/// The Indonesian texts an export file needs, resolved by the caller from the String Catalog so
/// the pure builders do not depend on the UI.
struct ExportTexts: Sendable {
    /// CSV and PDF table columns: date, type, amount, account, destination account, category,
    /// note (in this order).
    var headers: [String]
    var typeLabels: [TransactionType: String]
    var pdfTitle: String
    var pdfPeriod: String
    var pdfIncome: String
    var pdfExpense: String
    var pdfDifference: String
    var pdfCount: String
    /// `Halaman {page} dari {total}`.
    var pdfPage: @Sendable (_ page: Int, _ total: Int) -> String
    /// The period text when the export spans all data.
    var pdfAllData: String
    /// `1 Nov 2026 s/d 30 Nov 2026` from two formatted dates.
    var pdfRange: @Sendable (_ from: String, _ to: String) -> String

    func typeLabel(_ type: TransactionType) -> String { typeLabels[type] ?? type.rawValue }
}
