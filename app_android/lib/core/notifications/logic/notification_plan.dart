import '../../domain_rules/period.dart';
import '../../domain_rules/reconciliation.dart';
import '../../time/civil_date.dart';
import 'planned_notification.dart';

/// Id ranges, one per kind. The scheduler cancels the whole range before it
/// schedules again, so a changed setting never leaves a stale notification.
const int dailyIdBase = 1000;
const int reconcileMonthEndIdBase = 2000;
const int reconcileStaleIdBase = 3000;
const int monthEvaluationIdBase = 4000;

/// How many days of daily reminders are scheduled ahead. The schedule is
/// rebuilt whenever the app opens or its data changes, and by the background
/// sync, so this only bounds how long the reminders last without any run.
const int dailyHorizonDays = 14;
const int monthEndHorizon = 3;
const int staleHorizon = 4;
const int monthEvaluationHorizon = 3;

const int reconcileHour = 20;
const int evaluationHour = 9;

/// Every id the scheduler may own, for cancelling.
Iterable<int> get allScheduledIds sync* {
  for (var i = 0; i < dailyHorizonDays; i++) {
    yield dailyIdBase + i;
  }
  for (var i = 0; i < monthEndHorizon; i++) {
    yield reconcileMonthEndIdBase + i;
  }
  for (var i = 0; i < staleHorizon; i++) {
    yield reconcileStaleIdBase + i;
  }
  for (var i = 0; i < monthEvaluationHorizon; i++) {
    yield monthEvaluationIdBase + i;
  }
}

/// The user settings the plan depends on.
class NotificationPrefs {
  const NotificationPrefs({
    required this.dailyReminderTime,
    required this.reconcileEnabled,
    required this.budgetAlertEnabled,
  });

  /// `HH:MM`, or null when the daily reminder is off.
  final String? dailyReminderTime;
  final bool reconcileEnabled;
  final bool budgetAlertEnabled;
}

/// Parses `HH:MM`; null when malformed.
(int, int)? parseReminderTime(String? value) {
  if (value == null) {
    return null;
  }
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
  if (match == null) {
    return null;
  }
  return (int.parse(match.group(1)!), int.parse(match.group(2)!));
}

/// A moment still ahead of "now" (strictly later than [nowMinutes] today).
bool _isFuture(CivilDate date, int minutes, CivilDate today, int nowMinutes) =>
    date.isAfter(today) || (date == today && minutes > nowMinutes);

/// The scheduled notifications of APP_FLOWS "Notifikasi lokal", from the
/// user's settings and data.
///
/// * Daily reminder at the chosen time for the next [dailyHorizonDays] days,
///   except today's when a transaction dated today already exists.
/// * Reconcile reminder at 20:00 on the last day of the month, and weekly at
///   20:00 while an account is stale (anchored on the day the earliest account
///   became stale).
/// * Month evaluation at 09:00 on the 1st, opening the month that just ended.
///
/// [snapshotDates] holds, for every account that counts towards the total, the
/// date of its newest snapshot (null when it has none). Budget warnings are
/// not scheduled: they fire when a threshold is crossed (see
/// `budget_alert_policy.dart`).
List<PlannedNotification> planNotifications({
  required NotificationPrefs prefs,
  required CivilDate today,
  required int nowMinutes,
  required bool hasTransactionToday,
  required List<CivilDate?> snapshotDates,
}) {
  final plan = <PlannedNotification>[];

  final reminder = parseReminderTime(prefs.dailyReminderTime);
  if (reminder != null) {
    final minutes = reminder.$1 * 60 + reminder.$2;
    for (var i = 0; i < dailyHorizonDays; i++) {
      final date = today.addDays(i);
      if (i == 0 && (hasTransactionToday || minutes <= nowMinutes)) {
        continue;
      }
      plan.add(
        PlannedNotification(
          id: dailyIdBase + i,
          kind: NotificationKind.daily,
          date: date,
          hour: reminder.$1,
          minute: reminder.$2,
          payload: '/transactions/new',
        ),
      );
    }
  }

  if (prefs.reconcileEnabled) {
    final monthEnds = <CivilDate>{};
    for (
      var k = 0;
      k < monthEndHorizon + 1 && monthEnds.length < monthEndHorizon;
      k++
    ) {
      final end = YearMonth.of(today).addMonths(k).last;
      if (_isFuture(end, reconcileHour * 60, today, nowMinutes)) {
        monthEnds.add(end);
      }
    }
    var index = 0;
    for (final end in monthEnds) {
      plan.add(
        PlannedNotification(
          id: reconcileMonthEndIdBase + index++,
          kind: NotificationKind.reconcileMonthEnd,
          date: end,
          hour: reconcileHour,
          minute: 0,
          payload: '/reconcile',
        ),
      );
    }

    if (snapshotDates.isNotEmpty) {
      // An account is stale once `asOf - snapshot > staleAfterDays`, i.e. from
      // the day after `snapshot + staleAfterDays`. No snapshot = stale already.
      CivilDate? anchor;
      for (final snapshot in snapshotDates) {
        final staleFrom = snapshot == null
            ? today
            : snapshot.addDays(staleAfterDays + 1);
        if (anchor == null || staleFrom.isBefore(anchor)) {
          anchor = staleFrom;
        }
      }
      var added = 0;
      for (var k = 0; added < staleHorizon && k < 520; k++) {
        final date = anchor!.addDays(7 * k);
        if (!_isFuture(date, reconcileHour * 60, today, nowMinutes) ||
            monthEnds.contains(date)) {
          continue;
        }
        plan.add(
          PlannedNotification(
            id: reconcileStaleIdBase + added++,
            kind: NotificationKind.reconcileStale,
            date: date,
            hour: reconcileHour,
            minute: 0,
            payload: '/reconcile',
          ),
        );
      }
    }
  }

  if (prefs.budgetAlertEnabled) {
    var index = 0;
    for (
      var k = 0;
      k < monthEvaluationHorizon + 1 && index < monthEvaluationHorizon;
      k++
    ) {
      final month = YearMonth.of(today).addMonths(k);
      final date = month.first;
      if (!_isFuture(date, evaluationHour * 60, today, nowMinutes)) {
        continue;
      }
      plan.add(
        PlannedNotification(
          id: monthEvaluationIdBase + index++,
          kind: NotificationKind.monthEvaluation,
          date: date,
          hour: evaluationHour,
          minute: 0,
          payload: '/budget?month=${month.addMonths(-1)}',
        ),
      );
    }
  }
  return plan;
}
