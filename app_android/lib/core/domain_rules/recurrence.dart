import '../time/civil_date.dart';
import 'period.dart';

enum RecurringFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurringFrequency(this.value);

  final String value;

  static RecurringFrequency fromValue(String value) =>
      values.firstWhere((e) => e.value == value);
}

/// Bounds the search so a malformed rule can never loop for long.
const int _maxOccurrenceSteps = 200000;

/// The schedule fields of a recurring rule.
///
/// [dayOfWeek] is ISO (Monday = 1 ... Sunday = 7) and does not follow
/// `user_settings.week_start`, so occurrence IDs are identical on every
/// device. [endDate] is null when open-ended.
class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    this.dayOfWeek = 0,
    this.dayOfMonth = 0,
    this.monthOfYear = 0,
    this.endDate,
  });

  final RecurringFrequency frequency;
  final int intervalCount;

  /// Weekly.
  final int dayOfWeek;

  /// Monthly and yearly.
  final int dayOfMonth;

  /// Yearly.
  final int monthOfYear;
  final CivilDate startDate;
  final CivilDate? endDate;
}

/// The dates that are due, ascending: later than [lastGenerated] (or on/after
/// the start date when it is null) and on/before [today], never before the
/// start date nor after the end date (BUSINESS_RULES §5.1-§5.2).
///
/// A rule whose required fields are missing or out of range yields no
/// occurrences.
List<CivilDate> occurrences(
  RecurrenceRule rule,
  CivilDate? lastGenerated,
  CivilDate today,
) {
  if (rule.intervalCount < 1) {
    return const [];
  }
  var upper = today;
  final end = rule.endDate;
  if (end != null && end.isBefore(upper)) {
    upper = end;
  }

  final due = <CivilDate>[];
  for (var n = 0; n < _maxOccurrenceSteps; n++) {
    final date = _nthOccurrence(rule, n);
    if (date == null) {
      return const [];
    }
    if (date.isAfter(upper)) {
      // Dates grow with n, but the first dates of weekly/monthly/yearly rules
      // can precede the start date; only stop once past the upper bound.
      break;
    }
    if (date.isBefore(rule.startDate)) {
      continue;
    }
    if (lastGenerated != null && !date.isAfter(lastGenerated)) {
      continue;
    }
    due.add(date);
  }
  return due;
}

/// The n-th candidate date of the rule (n starts at 0). Candidates can fall
/// before the start date (the first week, month, or year); callers skip those.
CivilDate? _nthOccurrence(RecurrenceRule rule, int n) {
  final step = n * rule.intervalCount;
  final start = rule.startDate;

  switch (rule.frequency) {
    case RecurringFrequency.daily:
      return start.addDays(step);

    case RecurringFrequency.weekly:
      if (rule.dayOfWeek < 1 || rule.dayOfWeek > 7) {
        return null;
      }
      // The first week is the ISO (Monday-based) week that contains the start.
      final weekStart = start.addDays(-(start.weekday - 1));
      return weekStart.addDays(step * 7 + rule.dayOfWeek - 1);

    case RecurringFrequency.monthly:
      if (rule.dayOfMonth < 1 || rule.dayOfMonth > 31) {
        return null;
      }
      return _clampedDate(YearMonth.of(start).addMonths(step), rule.dayOfMonth);

    case RecurringFrequency.yearly:
      if (rule.dayOfMonth < 1 ||
          rule.dayOfMonth > 31 ||
          rule.monthOfYear < 1 ||
          rule.monthOfYear > 12) {
        return null;
      }
      return _clampedDate(
        YearMonth(start.year + step, rule.monthOfYear),
        rule.dayOfMonth,
      );
  }
}

/// The given day of the month, or the month's last day when it is shorter
/// (31 -> 30 Nov, 29 Feb -> 28 Feb in a non-leap year).
CivilDate _clampedDate(YearMonth month, int day) {
  final lastDay = CivilDate.daysInMonth(month.year, month.month);
  return CivilDate(month.year, month.month, day < lastDay ? day : lastDay);
}

/// The first date strictly after [after] on which the rule falls, or null when
/// it has ended (or can never fall again). Used to show "Berikutnya".
CivilDate? nextOccurrence(RecurrenceRule rule, CivilDate after) {
  // The search window covers one full step of the rule, with room for a
  // clamped month end, so a rule that still has a next date always shows it.
  final windowDays = switch (rule.frequency) {
    RecurringFrequency.daily => rule.intervalCount + 1,
    RecurringFrequency.weekly => rule.intervalCount * 7 + 7,
    RecurringFrequency.monthly => rule.intervalCount * 31 + 31,
    RecurringFrequency.yearly => rule.intervalCount * 366 + 366,
  };
  final due = occurrences(rule, after, after.addDays(windowDays));
  return due.isEmpty ? null : due.first;
}
