import 'dart:async';

import 'package:timezone/timezone.dart' as tz;

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_id.dart';
import '../database/app_database.dart';
import '../database/mappers/row_mappers.dart';
import '../domain_rules/budget.dart';
import '../domain_rules/period.dart';
import '../domain_rules/reconciliation.dart';
import '../domain_rules/types.dart';
import '../money/money_formatter.dart';
import '../time/civil_date.dart';
import '../time/civil_date_format.dart';
import '../time/user_clock.dart';
import 'logic/budget_alert_policy.dart';
import 'logic/notification_plan.dart';
import 'logic/planned_notification.dart';
import 'notification_service.dart';

const String _sentKey = 'budget_alerts_sent';
const int _budgetAlertIdBase = 5000;

/// Builds the local notification schedule from the database and shows budget
/// warnings (APP_FLOWS "Notifikasi lokal"). It reads the database directly, so
/// the same code runs in the app and in the background sync isolate.
///
/// Every call is serialised: two overlapping runs would otherwise cancel each
/// other's schedule or announce one warning twice.
class NotificationScheduler {
  NotificationScheduler({
    required this._db,
    required this._service,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final NotificationService _service;
  final DateTime Function() _now;

  Future<void> _tail = Future.value();

  // Notification text is localized without a BuildContext: the app is
  // Indonesian only, and a background isolate has no widgets.
  AppLocalizations get _l10n => AppLocalizationsId();

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _tail.then((_) => task());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Rebuilds the scheduled notifications for the current settings and data,
  /// then announces any budget threshold that was crossed.
  Future<void> refresh() => _serial(() async {
    await _reschedule();
    await _announceBudget();
  });

  /// Cancels everything this scheduler may have scheduled (sign-out).
  Future<void> cancelAll() =>
      _serial(() => _service.cancelPending(allScheduledIds.toSet()));

  Future<void> _reschedule() async {
    await _service.cancelPending(allScheduledIds.toSet());
    final settings = await _db.userSettingsDao.current();
    if (settings == null) {
      return;
    }
    final clock = UserClock(settings.timezone, now: _now);
    final today = clock.today();
    final local = clock.now();

    final accounts = await _db.accountsDao.allActive();
    final snapshots = [
      for (final row in await _db.balanceSnapshotsDao.allActive())
        row.toDomain(),
    ];
    final snapshotDates = <CivilDate?>[
      for (final account in accounts)
        if (inTotalAccount(account))
          latestSnapshot(snapshots, account.id, today)?.date,
    ];

    final plan = planNotifications(
      prefs: NotificationPrefs(
        dailyReminderTime: settings.dailyReminderTime,
        reconcileEnabled: settings.reconcileReminderEnabled,
        budgetAlertEnabled: settings.budgetAlertEnabled,
      ),
      today: today,
      nowMinutes: local.hour * 60 + local.minute,
      hasTransactionToday: await _db.transactionsDao.hasPostedOn(today),
      snapshotDates: snapshotDates,
    );
    for (final planned in plan) {
      final text = _text(planned);
      await _service.schedule(
        id: planned.id,
        when: tz.TZDateTime(
          clock.location,
          planned.date.year,
          planned.date.month,
          planned.date.day,
          planned.hour,
          planned.minute,
        ),
        title: text.$1,
        body: text.$2,
        payload: planned.payload,
        channel: NotificationChannel.reminders,
      );
    }
  }

  /// A live account that counts towards the total (archived accounts count).
  static bool inTotalAccount(AccountRow account) =>
      account.includeInTotal && account.deletedAt == null;

  (String, String) _text(PlannedNotification planned) {
    final l10n = _l10n;
    return switch (planned.kind) {
      NotificationKind.daily => (l10n.notifDailyTitle, l10n.notifDailyBody),
      NotificationKind.reconcileMonthEnd => (
        l10n.notifReconcileTitle,
        l10n.notifReconcileBody,
      ),
      NotificationKind.reconcileStale => (
        l10n.notifStaleTitle,
        l10n.notifStaleBody,
      ),
      NotificationKind.monthEvaluation => (
        l10n.notifEvalTitle,
        // The evaluation covers the month that just ended.
        l10n.notifEvalBody(
          formatYearMonth(YearMonth.of(planned.date).addMonths(-1)),
        ),
      ),
    };
  }

  Future<void> _announceBudget() async {
    final settings = await _db.userSettingsDao.current();
    if (settings == null || !settings.budgetAlertEnabled) {
      return;
    }
    final clock = UserClock(settings.timezone, now: _now);
    final today = clock.today();
    final month = YearMonth.of(today);

    final goals = [
      for (final row in await _db.budgetGoalsDao.allActive()) row.toDomain(),
    ];
    final goal = effectiveGoal(goals, month);
    if (goal == null) {
      return;
    }
    final budget = computeBudget(
      [for (final row in await _db.accountsDao.allActive()) row.toDomain()],
      [for (final row in await _db.transactionsDao.allActive()) row.toDomain()],
      goal,
      month,
      today,
    );
    final sent = await _readSent();
    final plan = planBudgetAlerts(
      month: month,
      budget: budget,
      alreadyAnnounced: sent,
    );
    if (plan.alerts.isEmpty) {
      return;
    }
    // Without the permission nothing can be shown, so do not use up the
    // once-per-month announcement.
    if (!await _service.areEnabled()) {
      return;
    }
    await _writeSent(month, {...sent, ...plan.keysToRemember});
    final l10n = _l10n;
    for (final alert in plan.alerts) {
      final name = alert.allocation == Allocation.needs
          ? l10n.allocationNeeds
          : l10n.allocationWants;
      final hide = settings.hideAmounts;
      await _service.showNow(
        id:
            _budgetAlertIdBase +
            (alert.allocation == Allocation.needs ? 0 : 2) +
            (alert.level >= budgetLimitPercent ? 1 : 0),
        title: alert.level >= budgetLimitPercent
            ? l10n.notifBudgetLimitTitle(name)
            : l10n.notifBudgetWarnTitle(name),
        // With "sembunyikan nominal" on, the text carries no amount at all.
        body: hide
            ? l10n.notifBudgetBodyHidden(name, alert.level)
            : l10n.notifBudgetBody(
                name,
                formatRupiah(alert.actual),
                formatRupiah(alert.goalAmount),
                alert.level,
              ),
        payload: '/budget?month=$month',
        channel: NotificationChannel.budget,
      );
    }
  }

  Future<Set<String>> _readSent() async {
    final raw = await _db.syncStateDao.read(_sentKey);
    return raw == null || raw.isEmpty ? <String>{} : raw.split('\n').toSet();
  }

  /// Keeps only the current month's keys, so the list cannot grow forever.
  Future<void> _writeSent(YearMonth month, Set<String> keys) => _db.syncStateDao
      .write(_sentKey, keys.where((k) => k.startsWith('$month|')).join('\n'));
}
