/// The shortcuts of the export period picker.
enum ExportPreset: Sendable, Hashable, CaseIterable {
    case thisMonth
    case lastMonth
    case last3Months
    case thisYear
    case allData
}

/// A closed range of civil dates; both nil means all data.
struct ExportPeriod: Sendable, Equatable {
    var from: CivilDate?
    var to: CivilDate?

    var isAll: Bool { from == nil && to == nil }

    /// "Tanggal awal tidak boleh setelah tanggal akhir."
    var isValid: Bool {
        if isAll { return true }
        guard let from, let to else { return false }
        return !(from > to)
    }
}

/// The period of `preset` relative to `today` (the user's timezone). "3 bulan terakhir" is the
/// current month and the two before it, the same window the free plan can view (BUSINESS_RULES
/// §7).
func exportPeriod(for preset: ExportPreset, today: CivilDate) -> ExportPeriod {
    switch preset {
    case .thisMonth:
        return ExportPeriod(from: today.firstOfMonth, to: today.lastOfMonth)
    case .lastMonth:
        let last = today.firstOfMonth.adding(days: -1)
        return ExportPeriod(from: last.firstOfMonth, to: last.lastOfMonth)
    case .last3Months:
        var first = today.firstOfMonth
        for _ in 0..<2 { first = first.adding(days: -1).firstOfMonth }
        return ExportPeriod(from: first, to: today.lastOfMonth)
    case .thisYear:
        return ExportPeriod(
            from: CivilDate(year: today.year, month: 1, day: 1),
            to: CivilDate(year: today.year, month: 12, day: 31))
    case .allData:
        return ExportPeriod()
    }
}
