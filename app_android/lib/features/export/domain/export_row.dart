import '../../../core/domain_rules/types.dart';
import '../../../core/time/civil_date.dart';

/// One transaction of an export, with account and category names already
/// resolved. [amount] is whole rupiah, signed only for adjustments.
class ExportRow {
  const ExportRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
    this.note,
  });

  final CivilDate date;
  final TransactionType type;
  final int amount;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;
  final String? note;
}
