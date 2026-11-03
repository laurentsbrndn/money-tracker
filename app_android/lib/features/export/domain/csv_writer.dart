import 'dart:convert';

import '../../../core/domain_rules/types.dart';
import 'export_row.dart';

/// UTF-8 byte order mark, so Excel opens the file as UTF-8.
const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

/// RFC 4180 line ending.
const String _lineEnd = '\r\n';

/// Characters that make a spreadsheet read a cell as a formula (CSV
/// injection). `\t` and `\r` are included as OWASP recommends.
const String _formulaStarts = '=+-@\t\r';

/// A text cell safe to open in a spreadsheet: a leading formula character
/// gets a `'` in front, then RFC 4180 quoting for [delimiter], `"` and line
/// breaks. Numbers are not passed through here (a negative adjustment must
/// stay a number).
String csvTextCell(String value, String delimiter) {
  var text = value;
  if (text.isNotEmpty && _formulaStarts.contains(text[0])) {
    text = "'$text";
  }
  final needsQuotes =
      text.contains(delimiter) ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r');
  return needsQuotes ? '"${text.replaceAll('"', '""')}"' : text;
}

/// The CSV text (without BOM) of [rows]: header, then one line per row.
/// Columns: date `YYYY-MM-DD`, type, amount (whole rupiah), account,
/// destination account, category, note.
String buildCsv({
  required List<ExportRow> rows,
  required List<String> headers,
  required String Function(TransactionType type) typeLabel,
  required String delimiter,
}) {
  final buffer = StringBuffer()
    ..write(headers.map((h) => csvTextCell(h, delimiter)).join(delimiter))
    ..write(_lineEnd);
  for (final row in rows) {
    buffer
      ..write(
        [
          row.date.toString(),
          csvTextCell(typeLabel(row.type), delimiter),
          '${row.amount}',
          csvTextCell(row.accountName, delimiter),
          csvTextCell(row.toAccountName ?? '', delimiter),
          csvTextCell(row.categoryName ?? '', delimiter),
          csvTextCell(row.note ?? '', delimiter),
        ].join(delimiter),
      )
      ..write(_lineEnd);
  }
  return buffer.toString();
}

/// [buildCsv] as file bytes: BOM + UTF-8.
List<int> csvBytes(String csv) => [...utf8Bom, ...utf8.encode(csv)];
