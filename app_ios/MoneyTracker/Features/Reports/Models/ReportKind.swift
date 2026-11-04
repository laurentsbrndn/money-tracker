/// The reports of APP_FLOWS Flow 8.
enum ReportKind: CaseIterable, Identifiable, Sendable {
    /// Expenses of a month per category.
    case category
    /// Income of a month per source.
    case source
    /// Income, expense, and savings over 6 or 12 months.
    case trend
    /// A month against the month before.
    case comparison
    /// The differences the user did not record, per month.
    case unrecorded

    var id: Self { self }

    /// Premium only (BUSINESS_RULES §7): trend, comparison, and unrecorded differences.
    var premiumOnly: Bool {
        switch self {
        case .category, .source: false
        case .trend, .comparison, .unrecorded: true
        }
    }

    /// The report is about one month (the month selector is shown).
    var usesMonth: Bool {
        switch self {
        case .category, .source, .comparison: true
        case .trend, .unrecorded: false
        }
    }

    var title: String {
        switch self {
        case .category: String(localized: "Per kategori")
        case .source: String(localized: "Sumber income")
        case .trend: String(localized: "Tren")
        case .comparison: String(localized: "Perbandingan")
        case .unrecorded: String(localized: "Selisih tidak tercatat")
        }
    }
}
