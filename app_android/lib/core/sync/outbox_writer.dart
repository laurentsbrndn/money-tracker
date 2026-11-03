import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../time/timestamp_format.dart';
import 'entity_stores.dart';
import 'logic/outbox_coalescer.dart';
import 'logic/outbox_item.dart';

extension OutboxEntryItem on OutboxEntry {
  OutboxItem toItem() => OutboxItem(
    seq: seq,
    entity: entity,
    recordId: recordId,
    op: op,
    updatedAt: updatedAt,
    batchId: batchId,
    attempts: attempts,
    nextAttemptAt: nextAttemptAt,
  );
}

/// Writes data rows and their outbox entries in one local transaction
/// (SYNC_PROTOCOL §6). Every data write in the app goes through here, and a
/// sync is requested after the transaction commits.
class OutboxWriter {
  OutboxWriter({
    required this._db,
    required this._stores,
    required this._onCommitted,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final EntityStores _stores;
  final void Function() _onCommitted;
  final DateTime Function() _clock;

  /// Runs [body] in one transaction. All writes inside share [OutboxTx.now],
  /// so a new record has `created_at == updated_at`.
  Future<T> write<T>(Future<T> Function(OutboxTx tx) body) async {
    final result = await _db.transaction(() async {
      final tx = OutboxTx._(_db, _stores, truncateToMillis(_clock()));
      return body(tx);
    });
    _onCommitted();
    return result;
  }
}

class OutboxTx {
  OutboxTx._(this._db, this._stores, this.now);

  final AppDatabase _db;
  final EntityStores _stores;

  /// UTC, whole milliseconds. Use it for `created_at` of new rows.
  final DateTime now;

  /// Saves the whole [row] (a Drift row/companion with every column) as
  /// `pending` with `updated_at = now`, and queues an `upsert`.
  Future<void> upsert(String entity, String id, Insertable<Object?> row) async {
    final store = _stores.of(entity);
    await store.saveLocal(row, now);
    final json = await store.rowJson(id);
    final serverVersion = await store.serverVersionOf(id);
    await _enqueue(entity, id, 'upsert', jsonEncode(json), serverVersion);
  }

  /// Deletes the record: a tombstone plus a queued `delete`, or — when the
  /// server never saw it — the row simply disappears (SYNC_PROTOCOL §6.3.2).
  Future<void> delete(String entity, String id) async {
    final store = _stores.of(entity);
    final updatedAt = await store.updatedAtOf(id);
    if (updatedAt == null) {
      return;
    }
    final serverVersion = await store.serverVersionOf(id);
    final existing = await _existing(entity, id);
    final decision = decideOutboxWrite(
      existing: existing,
      op: 'delete',
      serverVersion: serverVersion,
    );
    if (decision is DropRecord) {
      final seq = decision.removeSeq;
      if (seq != null) {
        await _db.outboxDao.remove(seq);
      }
      await store.deleteHard(id);
      return;
    }
    await store.markDeleted(id, now);
    await _apply(decision, entity, id, 'delete', '');
  }

  /// Queues the stored row again after a refused push (SYNC_PROTOCOL §8.4,
  /// "memperbaiki"): a live row as `upsert`, a tombstone as `delete`.
  Future<void> requeue(String entity, String id) async {
    final store = _stores.of(entity);
    final json = await store.rowJson(id);
    if (json == null) {
      return;
    }
    await store.touch(id, now);
    final serverVersion = await store.serverVersionOf(id);
    if (json['deleted_at'] != null) {
      await _enqueue(entity, id, 'delete', '', serverVersion);
    } else {
      final fresh = await store.rowJson(id);
      await _enqueue(entity, id, 'upsert', jsonEncode(fresh), serverVersion);
    }
  }

  Future<List<OutboxItem>> _existing(String entity, String id) async => [
    for (final entry in await _db.outboxDao.findByRecord(entity, id))
      entry.toItem(),
  ];

  Future<void> _enqueue(
    String entity,
    String id,
    String op,
    String payload,
    int? serverVersion,
  ) async {
    final decision = decideOutboxWrite(
      existing: await _existing(entity, id),
      op: op,
      serverVersion: serverVersion,
    );
    await _apply(decision, entity, id, op, payload);
  }

  Future<void> _apply(
    OutboxWriteDecision decision,
    String entity,
    String id,
    String op,
    String payload,
  ) async {
    switch (decision) {
      case ReplaceEntry(:final seq):
        await _db.outboxDao.overwrite(
          seq,
          op: op,
          payload: payload,
          updatedAt: now,
        );
      case AppendEntry():
        await _db.outboxDao.enqueue(
          OutboxCompanion.insert(
            entity: entity,
            recordId: id,
            op: op,
            payload: Value(payload),
            updatedAt: now,
            createdAt: now,
          ),
        );
      case DropRecord():
        break;
    }
  }
}
