import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/money/money_formatter.dart';
import '../../../core/time/civil_date.dart';
import '../domain/export_pagination.dart';
import '../domain/export_row.dart';
import '../domain/export_summary.dart';
import '../domain/export_texts.dart';

const int _firstPageRows = 26;
const int _otherPageRows = 36;
const double _rowHeight = 17;

/// Builds the PDF page by page: each page is added, then the event loop gets
/// a turn and [onProgress] (0..1) fires, so a very large export keeps the
/// progress indicator moving. Uses the built-in Helvetica (Latin text only;
/// other characters print as `?`, see [pdfSafeText]).
Future<Uint8List> buildExportPdf({
  required List<ExportRow> rows,
  required String periodText,
  required ExportTexts texts,
  void Function(double progress)? onProgress,
}) async {
  final summary = ExportSummary.of(rows);
  final pages = paginateRows(rows.length, _firstPageRows, _otherPageRows);
  final document = pw.Document();
  for (var index = 0; index < pages.length; index++) {
    final (start, end) = pages[index];
    final slice = rows.sublist(start, end);
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (index == 0) ..._header(summary, periodText, texts),
            _table(slice, texts),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                texts.pdfPage(index + 1, pages.length),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
        ),
      ),
    );
    onProgress?.call((index + 1) / pages.length);
    await Future<void>.delayed(Duration.zero);
  }
  return document.save();
}

List<pw.Widget> _header(
  ExportSummary summary,
  String periodText,
  ExportTexts texts,
) => [
  pw.Text(
    pdfSafeText(texts.pdfTitle),
    style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
  ),
  pw.SizedBox(height: 4),
  pw.Text(
    '${pdfSafeText(texts.pdfPeriod)}: ${pdfSafeText(periodText)}',
    style: const pw.TextStyle(fontSize: 10),
  ),
  pw.SizedBox(height: 10),
  _summaryLine(texts.pdfIncome, formatRupiah(summary.income)),
  _summaryLine(texts.pdfExpense, formatRupiah(summary.expense)),
  _summaryLine(texts.pdfDifference, formatSignedRupiah(summary.difference)),
  _summaryLine(texts.pdfCount, '${summary.count}'),
  pw.SizedBox(height: 12),
];

pw.Widget _summaryLine(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 2),
  child: pw.Row(
    children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          pdfSafeText(label),
          style: const pw.TextStyle(fontSize: 10),
        ),
      ),
      pw.Text(
        value,
        style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

// Date, type, amount, account (with destination), category/note.
const List<double> _columnWidths = [58, 62, 78, 120, 0];

pw.Widget _table(List<ExportRow> rows, ExportTexts texts) {
  pw.Widget cell(String text, int column, {bool bold = false}) => pw.SizedBox(
    width: _columnWidths[column] == 0 ? null : _columnWidths[column],
    height: _rowHeight,
    child: pw.Align(
      alignment: column == 2
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        child: pw.Text(
          text,
          maxLines: 1,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
    ),
  );

  pw.Widget line(
    List<String> values, {
    bool bold = false,
    bool shaded = false,
  }) => pw.Container(
    color: shaded ? PdfColors.grey200 : null,
    child: pw.Row(
      children: [
        for (var i = 0; i < 4; i++) cell(values[i], i, bold: bold),
        pw.Expanded(child: cell(values[4], 4, bold: bold)),
      ],
    ),
  );

  final headers = texts.headers;
  return pw.Column(
    children: [
      line(
        [
          pdfSafeText(headers[0], maxLength: 14),
          pdfSafeText(headers[1], maxLength: 14),
          pdfSafeText(headers[2], maxLength: 16),
          pdfSafeText(headers[3], maxLength: 26),
          '${pdfSafeText(headers[5], maxLength: 18)} / ${pdfSafeText(headers[6], maxLength: 18)}',
        ],
        bold: true,
        shaded: true,
      ),
      for (final row in rows)
        line([
          _date(row.date),
          pdfSafeText(texts.typeLabel(row.type), maxLength: 14),
          formatRupiah(row.amount),
          pdfSafeText(
            row.toAccountName == null
                ? row.accountName
                : '${row.accountName} > ${row.toAccountName}',
            maxLength: 26,
          ),
          pdfSafeText(
            [
              if (row.categoryName != null) row.categoryName!,
              if (row.note != null && row.note!.isNotEmpty) row.note!,
            ].join(' / '),
            maxLength: 40,
          ),
        ]),
    ],
  );
}

String _date(CivilDate date) => date.toString();
