import '../../../../core/database/app_database.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// "Setiap 2 minggu pada hari Rabu": the schedule of a rule in words.
String describeSchedule(AppLocalizations l10n, RecurringRuleRow rule) {
  final n = rule.intervalCount;
  final every = n == 1;
  final dow = rule.dayOfWeek ?? 1;
  final dom = '${rule.dayOfMonth ?? 1}';
  return switch (rule.frequency) {
    'daily' =>
      every ? l10n.recurringScheduleDaily : l10n.recurringScheduleDailyN('$n'),
    'weekly' =>
      every
          ? l10n.recurringScheduleWeekly(weekdayName(dow))
          : l10n.recurringScheduleWeeklyN('$n', weekdayName(dow)),
    'monthly' =>
      every
          ? l10n.recurringScheduleMonthly(dom)
          : l10n.recurringScheduleMonthlyN('$n', dom),
    _ =>
      every
          ? l10n.recurringScheduleYearly(dom, monthName(rule.monthOfYear ?? 1))
          : l10n.recurringScheduleYearlyN(
              '$n',
              dom,
              monthName(rule.monthOfYear ?? 1),
            ),
  };
}
