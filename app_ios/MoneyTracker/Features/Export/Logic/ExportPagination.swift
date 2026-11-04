/// Splits `total` rows into pages: the first page holds `firstPage` rows (it also carries the
/// summary), the others `perPage`. Returns half-open index ranges. An empty list yields one empty
/// page so the summary still prints.
func paginateRows(total: Int, firstPage: Int, perPage: Int) -> [Range<Int>] {
    var pages: [Range<Int>] = []
    var start = 0
    var size = firstPage
    repeat {
        let end = min(start + size, total)
        pages.append(start..<end)
        start = end
        size = perPage
    } while start < total
    return pages
}

/// Text for the PDF table: control characters and line breaks become spaces, and `maxLength`
/// cuts long notes with `...` (the same lengths as Flutter).
func pdfSafeText(_ value: String, maxLength: Int = 60) -> String {
    var text = ""
    for scalar in value.unicodeScalars {
        if scalar.value < 0x20 || scalar.value == 0x7F {
            text.unicodeScalars.append(" ")
        } else {
            text.unicodeScalars.append(scalar)
        }
    }
    guard text.count > maxLength else { return text }
    return String(text.prefix(maxLength - 3)) + "..."
}
