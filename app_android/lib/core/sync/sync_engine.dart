import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../ids/id_generator.dart';
import '../network/api_client_provider.dart';
import '../network/api_exception.dart';
import '../time/timestamp_format.dart';
import 'connectivity.dart';
import 'logic/backoff.dart';
import 'logic/push_batch_selector.dart';
import 'outbox_writer.dart';
import 'sync_providers.dart';
import 'sync_run_state.dart';

part 'sync_engine.g.dart';

const String lastSyncAtKey = 'last_sync_at';

/// One request failed in a way that retrying the same request cannot fix
/// (413/422 for a whole batch); the entries were already counted.
class _BatchRejected implements Exception {
  const _BatchRejected(this.message);

  final String message;
}

/// The sync cycle of SYNC_PROTOCOL §7: push the outbox, then pull changes.
/// Single-flight: a call during a run only asks for one more run afterwards.
@Riverpod(keepAlive: true)
class SyncEngine extends _$SyncEngine {
  bool _again = false;
  int _failureStreak = 0;

  @override
  SyncRunState build() => const SyncRunState();

  /// Delay before the cycle should be retried after offline/failed runs.
  Duration? get retryDelay =>
      _failureStreak == 0 ? null : backoffFor(_failureStreak);

  Future<SyncOutcome> runOnce() async {
    if (state.running) {
      _again = true;
      return SyncOutcome.skipped;
    }
    state = state.copyWith(running: true);
    SyncOutcome outcome;
    try {
      outcome = await _cycle();
      if (_again && outcome == SyncOutcome.synced) {
        _again = false;
        outcome = await _cycle();
      }
    } on Object catch (error) {
      // An unexpected error (bad payload, database failure) must not leave the
      // engine marked as running forever; it is retried with backoff.
      state = state.copyWith(lastError: error.runtimeType.toString());
      outcome = SyncOutcome.failed;
    }
    _again = false;
    if (outcome == SyncOutcome.synced) {
      _failureStreak = 0;
    } else if (outcome == SyncOutcome.offline ||
        outcome == SyncOutcome.failed) {
      _failureStreak++;
    }
    state = state.copyWith(running: false, outcome: outcome);
    return outcome;
  }

  /// First pull after login (SYNC_PROTOCOL §12): waits for a run in progress,
  /// then marks the initial sync done once a cycle completes.
  Future<SyncOutcome> runInitialSync() async {
    SyncOutcome outcome;
    do {
      outcome = await runOnce();
      if (outcome == SyncOutcome.skipped) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    } while (outcome == SyncOutcome.skipped);
    if (outcome == SyncOutcome.synced) {
      await ref
          .read(appDatabaseProvider)
          .syncStateDao
          .write(initialSyncDoneKey, 'true');
    }
    return outcome;
  }

  Future<SyncOutcome> _cycle() async {
    final status = ref.read(sessionControllerProvider).status;
    if (status != SessionStatus.authenticated) {
      return SyncOutcome.needsLogin;
    }
    if (!await checkOnline()) {
      return SyncOutcome.offline;
    }
    try {
      final token = await ref.read(tokenRefresherProvider).validAccessToken();
      if (token == null) {
        return SyncOutcome.needsLogin;
      }
      final repairKeys = await _push();
      await _pull();
      await _repair(repairKeys);
      await ref
          .read(appDatabaseProvider)
          .syncStateDao
          .write(lastSyncAtKey, formatTimestamp(DateTime.now()));
      return SyncOutcome.synced;
    } on _BatchRejected catch (rejected) {
      state = state.copyWith(lastError: rejected.message);
      return SyncOutcome.failed;
    } on DioException catch (error) {
      return _classify(error);
    }
  }

  Future<SyncOutcome> _classify(DioException error) async {
    final problem = ApiException.from(error);
    state = state.copyWith(lastError: problem?.code ?? error.type.name);
    if (problem != null) {
      if (problem.status == 401) {
        await ref.read(sessionControllerProvider.notifier).markNeedsLogin();
        return SyncOutcome.needsLogin;
      }
      return SyncOutcome.failed;
    }
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return SyncOutcome.offline;
      default:
        return SyncOutcome.failed;
    }
  }

  Future<Set<String>> _push() async {
    final repairKeys = <String>{};
    final db = ref.read(appDatabaseProvider);
    final remote = ref.read(syncRemoteProvider);
    final applier = ref.read(pushApplierProvider);
    while (true) {
      final entries = await db.outboxDao.all();
      final batch = selectPushBatch(
        [for (final entry in entries) entry.toItem()],
        DateTime.now(),
        const IdGenerator().newId,
      );
      if (batch == null) {
        return repairKeys;
      }
      if (!batch.isResend) {
        await db.outboxDao.markInFlight([
          for (final item in batch.items) item.seq,
        ], batch.batchId);
      }
      final bySeq = {for (final entry in entries) entry.seq: entry};
      final changes = [
        for (final item in batch.items) _wireChange(bySeq[item.seq]!),
      ];
      try {
        final results = await remote.push(batch.batchId, changes);
        repairKeys.addAll(
          await applier.apply(
            batch,
            results,
            DateTime.now(),
            await ref.read(pullApplierProvider).currentCursor(),
          ),
        );
      } on DioException catch (error) {
        final problem = ApiException.from(error);
        final status = problem?.status ?? 0;
        if (status >= 400 && status < 500 && status != 401 && status != 429) {
          final message = problem?.code ?? 'status_$status';
          await applier.applyBatchFailure(batch, message, DateTime.now());
          throw _BatchRejected(message);
        }
        rethrow;
      }
    }
  }

  Map<String, Object?> _wireChange(OutboxEntry entry) => {
    'entity': entry.entity,
    'op': entry.op,
    'id': entry.recordId,
    'updated_at': formatTimestamp(entry.updatedAt),
    if (entry.op == 'upsert') 'data': jsonDecode(entry.payload),
  };

  Future<void> _pull() async {
    final remote = ref.read(syncRemoteProvider);
    final applier = ref.read(pullApplierProvider);
    while (true) {
      final cursor = await applier.currentCursor();
      final page = await remote.pull(cursor);
      final written = await applier.apply(page);
      state = state.copyWith(pulledRows: state.pulledRows + written);
      if (!page.hasMore || page.nextCursor <= cursor) {
        return;
      }
    }
  }

  /// Re-fetches records whose stale push answer can no longer be delivered by
  /// a normal pull (SYNC_PROTOCOL §8.4). One scan from the start per cycle,
  /// however many records need it.
  Future<void> _repair(Set<String> keys) async {
    if (keys.isEmpty) {
      return;
    }
    final remote = ref.read(syncRemoteProvider);
    final applier = ref.read(pullApplierProvider);
    final pending = {...keys};
    var cursor = 0;
    while (pending.isNotEmpty) {
      final page = await remote.pull(cursor, limit: 1000);
      pending.removeAll(await applier.applyRepair(page, pending));
      if (!page.hasMore || page.nextCursor <= cursor) {
        return;
      }
      cursor = page.nextCursor;
    }
  }
}
