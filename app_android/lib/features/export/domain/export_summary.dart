import '../../../core/domain_rules/types.dart';
import 'export_row.dart';

/// Totals printed at the top of the PDF. Transfers and adjustments are not
/// income or expense (BUSINESS_RULES), so they only count in [count].
class ExportSummary {
  const ExportSummary({
    required this.income,
    required this.expense,
    required this.count,
  });

  factory ExportSummary.of(List<ExportRow> rows) {
    var income = 0;
    var expense = 0;
    for (final row in rows) {
      if (row.type == TransactionType.income) {
        income += row.amount;
      } else if (row.type == TransactionType.expense) {
        expense += row.amount;
      }
    }
    return ExportSummary(income: income, expense: expense, count: rows.length);
  }

  final int income;
  final int expense;
  final int count;

  int get difference => income - expense;
}
