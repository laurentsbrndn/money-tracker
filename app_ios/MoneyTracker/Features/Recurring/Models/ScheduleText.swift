import Foundation

private let indonesian = Locale(identifier: "id_ID")

/// "Senin" ... "Minggu" for an ISO weekday (Monday = 1), from the locale's symbols.
func weekdayName(_ isoWeekday: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = indonesian
    // `weekdaySymbols` starts on Sunday.
    return formatter.weekdaySymbols[isoWeekday % 7]
}

/// "Januari" ... "Desember".
func monthName(_ month: Int) -> String {
    let formatter = DateFormatter()
    formatter.locale = indonesian
    return formatter.monthSymbols[month - 1]
}

/// "Setiap 2 minggu pada hari Rabu": the schedule of a rule in words.
func describeSchedule(_ rule: RecurringRuleRecord) -> String {
    let n = rule.intervalCount
    let every = n == 1
    let weekday = weekdayName(rule.dayOfWeek ?? 1)
    let day = rule.dayOfMonth ?? 1
    switch rule.frequency {
    case "daily":
        return every ? String(localized: "Setiap hari") : String(localized: "Setiap \(n) hari")
    case "weekly":
        return every
            ? String(localized: "Setiap \(weekday)")
            : String(localized: "Setiap \(n) minggu pada hari \(weekday)")
    case "monthly":
        return every
            ? String(localized: "Setiap tanggal \(day)")
            : String(localized: "Setiap \(n) bulan pada tanggal \(day)")
    default:
        let month = monthName(rule.monthOfYear ?? 1)
        return every
            ? String(localized: "Setiap \(day) \(month)")
            : String(localized: "Setiap \(n) tahun pada \(day) \(month)")
    }
}
