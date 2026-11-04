/// How the CSV column separator is chosen (the export screen offers all three).
enum CsvDelimiterChoice: Sendable, Hashable {
    case auto
    case comma
    case semicolon
}

/// A locale whose decimal separator is this gets `;`: Excel there reads `,` as the decimal mark.
private let semicolonLocaleDecimalSeparator = ","

/// The one place the separator rule lives (same rule as Flutter, FRONTEND_FLUTTER.md §4.7): a
/// locale whose decimal separator is a comma (id-ID, most of Europe) gets `;`; a locale with a
/// decimal point (en-US) gets `,`.
func resolveCsvDelimiter(_ choice: CsvDelimiterChoice, deviceDecimalSeparator: String) -> String {
    switch choice {
    case .comma: ","
    case .semicolon: ";"
    case .auto: deviceDecimalSeparator == semicolonLocaleDecimalSeparator ? ";" : ","
    }
}
