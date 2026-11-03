import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/dashboard/application/dashboard_providers.dart';
import '../../l10n/generated/app_localizations_id.dart';
import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';
import '../domain_rules/period.dart';
import '../router/app_gate.dart';
import '../router/app_router.dart';
import '../router/route_paths.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

part 'notification_coordinator.g.dart';

/// The notification that cold-started the app is opened once per process,
/// even if the coordinator is rebuilt (for example after a logout).
bool _launchPayloadConsumed = false;

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  final l10n = AppLocalizationsId();
  final service = NotificationService(
    remindersChannelName: l10n.notifChannelReminders,
    budgetChannelName: l10n.notifChannelBudget,
  );
  ref.onDispose(service.dispose);
  return service;
}

@Riverpod(keepAlive: true)
NotificationScheduler notificationScheduler(Ref ref) => NotificationScheduler(
  db: ref.watch(appDatabaseProvider),
  service: ref.watch(notificationServiceProvider),
);

/// Keeps the local notifications in step with the app (FRONTEND_FLUTTER §4.5):
/// they are rebuilt when the app opens, comes back to the foreground, and
/// whenever settings, transactions, snapshots, accounts, or goals change —
/// which includes changes that a sync just pulled. It also opens the screen
/// of a tapped notification.
class NotificationCoordinator {
  NotificationCoordinator(this._ref);

  final Ref _ref;
  Timer? _debounce;
  StreamSubscription<Object?>? _dataChanges;
  StreamSubscription<String>? _taps;
  AppLifecycleListener? _lifecycle;

  void start() {
    final service = _ref.read(notificationServiceProvider);
    unawaited(service.ensureInitialized());
    _taps = service.taps.listen(_open);

    final db = _ref.read(appDatabaseProvider);
    _dataChanges = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.userSettings,
            db.transactions,
            db.balanceSnapshots,
            db.accounts,
            db.budgetGoals,
          ]),
        )
        .listen((_) => requestRefresh());
    _lifecycle = AppLifecycleListener(onResume: requestRefresh);
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_dataChanges?.cancel());
    unawaited(_taps?.cancel());
    _lifecycle?.dispose();
  }

  /// Rebuilds the schedule shortly (writes often come in bursts).
  void requestRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    // No notifications while the account is still being set up.
    if (_ref.read(appGateProvider) != AppGate.ready) {
      return;
    }
    try {
      await _ref.read(notificationSchedulerProvider).refresh();
    } on Object {
      // A failed refresh is retried by the next change or resume.
    }
  }

  /// Called when the gate opens: refresh, and open the notification that
  /// started the app.
  Future<void> onReady() async {
    requestRefresh();
    if (_launchPayloadConsumed) {
      return;
    }
    _launchPayloadConsumed = true;
    final payload = await _ref.read(notificationServiceProvider).launchPayload();
    if (payload != null) {
      _open(payload);
    }
  }

  Future<void> onSignedOut() =>
      _ref.read(notificationSchedulerProvider).cancelAll();

  void _open(String payload) {
    if (_ref.read(appGateProvider) != AppGate.ready) {
      return;
    }
    final router = _ref.read(appRouterProvider);
    final uri = Uri.parse(payload);
    if (uri.path == RoutePaths.budget) {
      final raw = uri.queryParameters['month'];
      if (raw != null) {
        try {
          _ref
              .read(selectedMonthProvider.notifier)
              .select(YearMonth.parse(raw));
        } on FormatException {
          // Ignore a malformed month; the budget tab opens on its own month.
        }
      }
      router.go(RoutePaths.budget);
      return;
    }
    unawaited(router.push<void>(uri.path));
  }
}

@Riverpod(keepAlive: true)
NotificationCoordinator notificationCoordinator(Ref ref) {
  // A logout replaces the database; rebuild so the new one is observed.
  ref.watch(appDatabaseProvider);
  final coordinator = NotificationCoordinator(ref)..start();
  ref
    ..onDispose(coordinator.dispose)
    ..listen(appGateProvider, (previous, next) {
      if (next == AppGate.ready && previous != AppGate.ready) {
        unawaited(coordinator.onReady());
      }
    }, fireImmediately: true)
    ..listen(sessionControllerProvider, (previous, next) {
      if (next.status == SessionStatus.signedOut &&
          previous?.status != SessionStatus.signedOut) {
        unawaited(coordinator.onSignedOut());
      }
    });
  return coordinator;
}
