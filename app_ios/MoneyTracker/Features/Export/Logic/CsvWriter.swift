import Foundation

/// UTF-8 byte order mark, so Excel opens the file as UTF-8.
let utf8Bom: [UInt8] = [0xEF, 0xBB, 0xBF]

/// RFC 4180 line ending.
private let lineEnd = "\r\n"

/// Characters that make a spreadsheet read a cell as a formula (CSV injection). Tab and CR are
/// included as OWASP recommends.
private let formulaStarts: Set<Character> = ["=", "+", "-", "@", "\t", "\r"]

/// A text cell safe to open in a spreadsheet: a leading formula character gets a `'` in front,
/// then RFC 4180 quoting for `delimiter`, `"`, and line breaks. Numbers are not passed through
/// here (a negative adjustment must stay a number).
func csvTextCell(_ value: String, delimiter: String) -> String {
    var text = value
    if let first = text.first, formulaStarts.contains(first) { text = "'" + text }
    // `\r\n` is one Character in Swift, so look at the scalars.
    let needsQuotes =
        text.contains(delimiter) || text.unicodeScalars.contains { $0 == "\"" || $0 == "\n" || $0 == "\r" }
    return needsQuotes ? "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : text
}

/// The CSV text (without BOM) of `rows`: header, then one line per row. Columns: date
/// `YYYY-MM-DD`, type, amount (whole rupiah), account, destination account, category, note.
func buildCsv(
    rows: [ExportRow], headers: [String], typeLabel: (TransactionType) -> String, delimiter: String
) -> String {
    var out = headers.map { csvTextCell($0, delimiter: delimiter) }.joined(separator: delimiter)
    out += lineEnd
    for row in rows {
        let cells = [
            row.date.description,
            csvTextCell(typeLabel(row.type), delimiter: delimiter),
            String(row.amount),
            csvTextCell(row.accountName, delimiter: delimiter),
            csvTextCell(row.toAccountName ?? "", delimiter: delimiter),
            csvTextCell(row.categoryName ?? "", delimiter: delimiter),
            csvTextCell(row.note ?? "", delimiter: delimiter),
        ]
        out += cells.joined(separator: delimiter) + lineEnd
    }
    return out
}

/// `buildCsv` as file bytes: BOM + UTF-8.
func csvBytes(_ csv: String) -> Data {
    Data(utf8Bom) + Data(csv.utf8)
}
