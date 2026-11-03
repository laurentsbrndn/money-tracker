import '../../../core/domain_rules/recurrence.dart';
import '../../../core/time/civil_date.dart';

/// A recurring rule as typed in the form: the transaction template and the
/// schedule (BUSINESS_RULES §5, DATA_MODEL §5).
class RecurringRuleInput {
  const RecurringRuleInput({
    required this.type,
    required this.amount,
    required this.accountId,
    required this.frequency,
    required this.intervalCount,
    required this.startDate,
    required this.mode,
    this.toAccountId,
    this.categoryId,
    this.allocation,
    this.source,
    this.note,
    this.dayOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.endDate,
  });

  /// `income`, `expense`, or `transfer`.
  final String type;
  final int? amount;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? allocation;
  final String? source;
  final String? note;
  final RecurringFrequency frequency;
  final int intervalCount;

  /// ISO weekday, for weekly rules.
  final int? dayOfWeek;

  /// For monthly and yearly rules.
  final int? dayOfMonth;

  /// For yearly rules.
  final int? monthOfYear;
  final CivilDate startDate;
  final CivilDate? endDate;

  /// `auto` or `confirm`.
  final String mode;
}
