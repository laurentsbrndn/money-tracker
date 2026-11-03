import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/recurrence.dart';
import '../../../core/time/civil_date.dart';
import 'recurring_rule_status.dart';

/// Drift row → the pure schedule of `core/domain_rules`.
extension RecurringRuleRowSchedule on RecurringRuleRow {
  RecurrenceRule toRecurrenceRule() => RecurrenceRule(
    frequency: RecurringFrequency.fromValue(frequency),
    intervalCount: intervalCount,
    startDate: startDate,
    dayOfWeek: dayOfWeek ?? 0,
    dayOfMonth: dayOfMonth ?? 0,
    monthOfYear: monthOfYear ?? 0,
    endDate: endDate,
  );

  /// The next date the rule falls on after today, or null when it has ended.
  CivilDate? nextDate(CivilDate today) {
    // A date that was already created is not "next" any more.
    var after = today.addDays(-1);
    final last = lastGeneratedDate;
    if (last != null && last.isAfter(after)) {
      after = last;
    }
    return nextOccurrence(toRecurrenceRule(), after);
  }

  RecurringRuleStatus statusAt(CivilDate today, {required bool premium}) {
    if (isPaused) {
      return premium
          ? RecurringRuleStatus.paused
          : RecurringRuleStatus.pausedNoPremium;
    }
    return nextDate(today) == null
        ? RecurringRuleStatus.ended
        : RecurringRuleStatus.active;
  }
}
