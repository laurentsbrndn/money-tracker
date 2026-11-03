import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';
import '../network/api_client_provider.dart';
import '../time/timestamp_format.dart';
import 'connectivity.dart';
import 'sync_engine.dart';
import 'sync_run_state.dart';

part 'sync_scheduler.g.dart';

const String foregroundSinceKey = 'foreground_since';
const Duration _debounce = Duration(seconds: 2);

/// While the app is open it rewrites [foregroundSinceKey] this often...
const Duration foregroundHeartbeat = Duration(seconds: 60);

/// ...and the background task ignores a marker older than this, so a crash or
/// force-stop blocks it for at most this long.
const Duration foregroundMarkerMaxAge = Duration(minutes: 3);

/// Decides when the engine runs (SYNC_PROTOCOL §7 triggers): 2 seconds after a
/// local write, on resume, when the connection returns, after login, and again
/// after a failure following its backoff.
class SyncScheduler {
  SyncScheduler(this._ref);

  final Ref _ref;
  Timer? _debounceTimer;
  Timer? _followUpTimer;
  Timer? _heartbeat;
  AppLifecycleListener? _lifecycle;

  void start() {
    _lifecycle = AppLifecycleListener(onResume: _onResume, onPause: _onPause);
    unawaited(_markForeground(true));
  }

  void dispose() {
    _debounceTimer?.cancel();
    _followUpTimer?.cancel();
    _heartbeat?.cancel();
    _lifecycle?.dispose();
  }

  /// Called after every local write.
  void requestSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// Runs now (pull-to-refresh, resume, connection back, login).
  Future<SyncOutcome> syncNow() async {
    _debounceTimer?.cancel();
    final outcome = await _ref.read(syncEngineProvider.notifier).runOnce();
    await _scheduleFollowUp(outcome);
    return outcome;
  }

  Future<void> _scheduleFollowUp(SyncOutcome outcome) async {
    _followUpTimer?.cancel();
    Duration? delay;
    if (outcome == SyncOutcome.offline || outcome == SyncOutcome.failed) {
      delay = _ref.read(syncEngineProvider.notifier).retryDelay;
    } else if (outcome == SyncOutcome.synced) {
      final due = await _ref
          .read(appDatabaseProvider)
          .outboxDao
          .earliestRetryAt();
      if (due != null) {
        final wait = due.difference(DateTime.now());
        delay = wait < const Duration(seconds: 1)
            ? const Duration(seconds: 1)
            : wait;
      }
    }
    if (delay != null) {
      _followUpTimer = Timer(delay, () => unawaited(syncNow()));
    }
  }

  void _onResume() {
    unawaited(_resume());
  }

  Future<void> _resume() async {
    // The background task may have changed the database from another isolate;
    // streams only hear about writes made in this one.
    final db = _ref.read(appDatabaseProvider);
    db.markTablesUpdated(db.allTables);
    _ref.read(tokenRefresherProvider).reload();
    await _markForeground(true);
    if (_ref.read(sessionControllerProvider).status ==
        SessionStatus.authenticated) {
      await syncNow();
    }
  }

  void _onPause() {
    unawaited(_markForeground(false));
  }

  /// Tells the background task whether the app is open, so the two never
  /// refresh the rotating refresh token at the same time.
  Future<void> _markForeground(bool foreground) async {
    _heartbeat?.cancel();
    if (foreground) {
      _heartbeat = Timer.periodic(
        foregroundHeartbeat,
        (_) => unawaited(_writeMarker(true)),
      );
    }
    await _writeMarker(foreground);
  }

  Future<void> _writeMarker(bool foreground) async {
    final dao = _ref.read(appDatabaseProvider).syncStateDao;
    try {
      if (foreground) {
        await dao.write(foregroundSinceKey, formatTimestamp(DateTime.now()));
      } else {
        await dao.remove(foregroundSinceKey);
      }
    } on Object {
      // The database may be mid-reset (logout); the next resume rewrites it.
    }
  }
}

@Riverpod(keepAlive: true)
SyncScheduler syncScheduler(Ref ref) {
  final scheduler = SyncScheduler(ref);
  ref.listen(isOnlineProvider, (previous, next) {
    if (next.value == true && previous?.value == false) {
      unawaited(scheduler.syncNow());
    }
  });
  ref.listen(sessionControllerProvider, (previous, next) {
    if (next.status == SessionStatus.authenticated &&
        previous?.status != SessionStatus.authenticated) {
      unawaited(scheduler.syncNow());
    }
  });
  ref.onDispose(scheduler.dispose);
  scheduler.start();
  return scheduler;
}
