import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/billing/entitlement_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/notifications/notification_coordinator.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/router/app_gate.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/time/user_clock.dart';
import '../../../l10n/generated/app_localizations_id.dart';
import '../data/recurring_generator.dart';
import '../data/recurring_repository.dart';

part 'recurring_providers.g.dart';

@Riverpod(keepAlive: true)
RecurringRepository recurringRepository(Ref ref) => RecurringRepository(
  db: ref.watch(appDatabaseProvider),
  writer: ref.watch(outboxWriterProvider),
  isPremium: () => ref.read(isPremiumProvider.future),
);

@Riverpod(keepAlive: true)
RecurringGenerator recurringGenerator(Ref ref) => RecurringGenerator(
  db: ref.watch(appDatabaseProvider),
  writer: ref.watch(outboxWriterProvider),
  today: () => ref.read(userClockProvider).today(),
  isPremium: () => ref.read(isPremiumProvider.future),
);

// The providers below return Drift row types, which riverpod_generator cannot
// see, so they are declared by hand.

/// Live recurring rules, in creation order.
final recurringRulesProvider =
    StreamProvider.autoDispose<List<RecurringRuleRow>>(
      (ref) => ref
          .watch(recurringRepositoryProvider)
          .watchAll()
          .map(
            (rules) =>
                [...rules]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          ),
    );

final recurringRuleProvider = FutureProvider.autoDispose
    .family<RecurringRuleRow?, String>(
      (ref, id) => ref.watch(recurringRepositoryProvider).find(id),
    );

/// Transactions of `confirm` rules waiting to be recorded or skipped.
final pendingTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionRow>>(
      (ref) => ref.watch(appDatabaseProvider).transactionsDao.watchPending(),
    );

const int _confirmNotificationId = 6000;

/// Creates the occurrences that came due (FRONTEND_FLUTTER §3, BUSINESS_RULES
/// §5.2) whenever the app is ready, comes back to the foreground, a sync
/// changed the rules, or premium turned on; and announces the ones that wait
/// for confirmation.
class RecurringCoordinator {
  RecurringCoordinator(this._ref);

  final Ref _ref;
  Timer? _debounce;
  StreamSubscription<Object?>? _changes;
  AppLifecycleListener? _lifecycle;
  bool _running = false;
  bool _again = false;

  void start() {
    final db = _ref.read(appDatabaseProvider);
    _changes = db
        .tableUpdates(TableUpdateQuery.onTable(db.recurringRules))
        .listen((_) => requestRun());
    _lifecycle = AppLifecycleListener(onResume: requestRun);
  }

  void dispose() {
    _debounce?.cancel();
    unawaited(_changes?.cancel());
    _lifecycle?.dispose();
  }

  void requestRun() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(_run()));
  }

  Future<void> _run() async {
    // Nothing is created while the account is still being set up.
    if (_ref.read(appGateProvider) != AppGate.ready) {
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      final result = await _ref.read(recurringGeneratorProvider).run();
      if (result.pendingConfirmation > 0) {
        await _announce(result.pendingConfirmation);
      }
    } on Object {
      // Retried by the next change or resume.
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        requestRun();
      }
    }
  }

  Future<void> _announce(int count) async {
    final service = _ref.read(notificationServiceProvider);
    if (!await service.areEnabled()) {
      return;
    }
    final l10n = AppLocalizationsId();
    await service.showNow(
      id: _confirmNotificationId,
      title: l10n.notifRecurringTitle,
      body: l10n.notifRecurringBody('$count'),
      payload: RoutePaths.transactions,
      channel: NotificationChannel.reminders,
    );
  }
}

@Riverpod(keepAlive: true)
RecurringCoordinator recurringCoordinator(Ref ref) {
  // A logout replaces the database; rebuild so the new one is observed.
  ref.watch(appDatabaseProvider);
  final coordinator = RecurringCoordinator(ref)..start();
  ref
    ..onDispose(coordinator.dispose)
    ..listen(appGateProvider, (previous, next) {
      if (next == AppGate.ready && previous != AppGate.ready) {
        coordinator.requestRun();
      }
    }, fireImmediately: true)
    ..listen(isPremiumProvider, (previous, next) {
      if ((next.value ?? false) && !(previous?.value ?? false)) {
        coordinator.requestRun();
      }
    });
  return coordinator;
}
