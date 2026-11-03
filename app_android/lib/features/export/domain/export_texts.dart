import '../../../core/domain_rules/types.dart';

/// The Indonesian texts an export file needs, resolved by the caller from
/// `app_id.arb` so the pure builders do not depend on Flutter.
class ExportTexts {
  const ExportTexts({
    required this.headers,
    required this.typeLabel,
    required this.pdfTitle,
    required this.pdfPeriod,
    required this.pdfIncome,
    required this.pdfExpense,
    required this.pdfDifference,
    required this.pdfCount,
    required this.pdfPage,
    required this.pdfAllData,
    required this.pdfRange,
  });

  /// CSV and PDF table columns: date, type, amount, account, destination
  /// account, category, note (in this order).
  final List<String> headers;
  final String Function(TransactionType type) typeLabel;
  final String pdfTitle;
  final String pdfPeriod;
  final String pdfIncome;
  final String pdfExpense;
  final String pdfDifference;
  final String pdfCount;

  /// `Halaman {page} dari {total}`.
  final String Function(int page, int total) pdfPage;

  /// The period text when the export spans all data.
  final String pdfAllData;

  /// `1 Nov 2026 s/d 30 Nov 2026` from two formatted dates.
  final String Function(String from, String to) pdfRange;
}
