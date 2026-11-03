import '../../../core/database/app_database.dart';
import '../../../core/time/civil_date.dart';

/// What the entry form collects before saving (APP_FLOWS Flow 3). [existing]
/// is set when editing.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.accountId,
    required this.date,
    this.toAccountId,
    this.categoryId,
    this.allocation,
    this.source,
    this.note,
    this.fee,
    this.existing,
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
  final CivilDate date;

  /// Admin fee of a transfer, saved as its own linked expense.
  final int? fee;
  final TransactionRow? existing;
}
