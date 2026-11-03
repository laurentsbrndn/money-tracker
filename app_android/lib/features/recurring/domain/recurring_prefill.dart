import '../../../core/time/civil_date.dart';

/// What the transaction form hands to the recurring form when the user taps
/// "Jadikan berulang" (APP_FLOWS Flow 10): the transaction becomes the
/// template, and its date the first occurrence.
class RecurringPrefill {
  const RecurringPrefill({
    required this.type,
    required this.startDate,
    this.amount,
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.allocation,
    this.source,
    this.note,
  });

  final String type;
  final int? amount;
  final String? accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? allocation;
  final String? source;
  final String? note;
  final CivilDate startDate;
}
