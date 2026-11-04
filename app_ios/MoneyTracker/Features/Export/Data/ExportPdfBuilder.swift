import UIKit

private let firstPageRows = 26
private let otherPageRows = 36
private let rowHeight: CGFloat = 17
private let pageSize = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)  // A4
private let margin: CGFloat = 28
/// Date, type, amount, account (with destination); the last column takes the rest.
private let columnWidths: [CGFloat] = [58, 62, 78, 120]

/// Builds the PDF page by page with `UIGraphicsPDFRenderer`, streaming to a file so a very large
/// export never holds the whole document in memory. `onProgress` (0...1) fires after each page.
/// Call it off the main thread. Long notes are cut (`pdfSafeText`).
enum ExportPdfBuilder {
    static func write(
        rows: [ExportRow], periodText: String, texts: ExportTexts, to url: URL,
        onProgress: @Sendable (Double) -> Void
    ) throws {
        let summary = ExportSummary(of: rows)
        let pages = paginateRows(total: rows.count, firstPage: firstPageRows, perPage: otherPageRows)
        let renderer = UIGraphicsPDFRenderer(bounds: pageSize)
        try renderer.writePDF(to: url) { context in
            for (index, range) in pages.enumerated() {
                context.beginPage()
                var y = margin
                if index == 0 { y = drawHeader(summary, periodText: periodText, texts: texts, y: y) }
                drawTable(rows[range], texts: texts, y: y)
                let footer = texts.pdfPage(index + 1, pages.count)
                draw(
                    footer, in: CGRect(
                        x: margin, y: pageSize.height - margin - 10,
                        width: pageSize.width - 2 * margin, height: 10),
                    font: .systemFont(ofSize: 8), alignment: .right)
                onProgress(Double(index + 1) / Double(pages.count))
            }
        }
    }

    private static func drawHeader(
        _ summary: ExportSummary, periodText: String, texts: ExportTexts, y start: CGFloat
    ) -> CGFloat {
        var y = start
        let width = pageSize.width - 2 * margin
        draw(
            pdfSafeText(texts.pdfTitle), in: CGRect(x: margin, y: y, width: width, height: 24),
            font: .boldSystemFont(ofSize: 18))
        y += 28
        draw(
            "\(pdfSafeText(texts.pdfPeriod)): \(pdfSafeText(periodText))",
            in: CGRect(x: margin, y: y, width: width, height: 14), font: .systemFont(ofSize: 10))
        y += 24
        let lines: [(String, String)] = [
            (texts.pdfIncome, MoneyFormatter.rupiah(summary.income)),
            (texts.pdfExpense, MoneyFormatter.rupiah(summary.expense)),
            (texts.pdfDifference, MoneyFormatter.signedRupiah(summary.difference)),
            (texts.pdfCount, String(summary.count)),
        ]
        for (label, value) in lines {
            draw(
                pdfSafeText(label), in: CGRect(x: margin, y: y, width: 110, height: 14),
                font: .systemFont(ofSize: 10))
            draw(
                value, in: CGRect(x: margin + 110, y: y, width: width - 110, height: 14),
                font: .boldSystemFont(ofSize: 10))
            y += 14
        }
        return y + 12
    }

    private static func drawTable(_ rows: ArraySlice<ExportRow>, texts: ExportTexts, y start: CGFloat) {
        var y = start
        let h = texts.headers
        let restWidth = pageSize.width - 2 * margin - columnWidths.reduce(0, +)
        func line(_ values: [String], bold: Bool, shaded: Bool) {
            if shaded {
                UIColor(white: 0.9, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: rowHeight))
            }
            var x = margin
            for column in 0..<5 {
                let width = column < 4 ? columnWidths[column] : restWidth
                draw(
                    values[column],
                    in: CGRect(x: x + 3, y: y + 4, width: width - 6, height: rowHeight - 4),
                    font: bold ? .boldSystemFont(ofSize: 8) : .systemFont(ofSize: 8),
                    alignment: column == 2 ? .right : .left)
                x += width
            }
            y += rowHeight
        }
        line(
            [
                pdfSafeText(h[0], maxLength: 14), pdfSafeText(h[1], maxLength: 14),
                pdfSafeText(h[2], maxLength: 16), pdfSafeText(h[3], maxLength: 26),
                "\(pdfSafeText(h[5], maxLength: 18)) / \(pdfSafeText(h[6], maxLength: 18))",
            ], bold: true, shaded: true)
        for row in rows {
            let account = row.toAccountName.map { "\(row.accountName) > \($0)" } ?? row.accountName
            var detail: [String] = []
            if let category = row.categoryName { detail.append(category) }
            if let note = row.note, !note.isEmpty { detail.append(note) }
            line(
                [
                    row.date.description, pdfSafeText(texts.typeLabel(row.type), maxLength: 14),
                    MoneyFormatter.rupiah(row.amount), pdfSafeText(account, maxLength: 26),
                    pdfSafeText(detail.joined(separator: " / "), maxLength: 40),
                ], bold: false, shaded: false)
        }
    }

    private static func draw(
        _ text: String, in rect: CGRect, font: UIFont, alignment: NSTextAlignment = .left
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font, .paragraphStyle: style, .foregroundColor: UIColor.black,
            ])
    }
}
