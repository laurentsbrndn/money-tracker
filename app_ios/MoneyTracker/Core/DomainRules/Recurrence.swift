enum RecurringFrequency: String, Sendable {
    case daily
    case weekly
    case monthly
    case yearly
}

/// Schedule fields of a recurring rule.
///
/// `dayOfWeek` is ISO (Monday = 1 ... Sunday = 7) and does not follow
/// `user_settings.week_start`, so occurrence IDs are identical on every device. `endDate` is
/// nil when open-ended.
struct RecurrenceRule: Sendable {
    var frequency: RecurringFrequency
    var intervalCount: Int
    /// weekly
    var dayOfWeek: Int
    /// monthly, yearly
    var dayOfMonth: Int
    /// yearly
    var monthOfYear: Int
    var startDate: CivilDate
    var endDate: CivilDate?
}

extension DomainRules {
    /// Bounds the search so a malformed rule can never loop for long.
    private static let maxOccurrenceSteps = 200_000

    /// The dates that are due, ascending: later than `lastGenerated` (or on/after `startDate`
    /// when it is nil) and on/before `today`, never before `startDate` nor after `endDate`
    /// (§5.1–§5.2).
    ///
    /// A rule whose required fields are missing or out of range yields no occurrences.
    static func occurrences(
        rule: RecurrenceRule, lastGenerated: CivilDate?, today: CivilDate
    ) -> [CivilDate] {
        guard rule.intervalCount >= 1 else { return [] }
        var upper = today
        if let end = rule.endDate, end < upper {
            upper = end
        }

        var due: [CivilDate] = []
        for n in 0..<maxOccurrenceSteps {
            guard let date = nthOccurrence(rule: rule, n: n) else { return [] }
            // Dates grow with n, but the first candidates of weekly/monthly/yearly rules can
            // precede startDate; only stop once past the upper bound.
            if date > upper { break }
            if date < rule.startDate { continue }
            if let last = lastGenerated, date <= last { continue }
            due.append(date)
        }
        return due
    }

    /// The n-th candidate date of the rule (n starts at 0). Candidates can fall before
    /// `startDate` (the first week, month, or year); callers skip those.
    private static func nthOccurrence(rule: RecurrenceRule, n: Int) -> CivilDate? {
        let step = n * rule.intervalCount
        let start = rule.startDate

        switch rule.frequency {
        case .daily:
            return start.adding(days: step)

        case .weekly:
            guard (1...7).contains(rule.dayOfWeek) else { return nil }
            // The first week is the ISO (Monday-based) week that contains startDate.
            let weekStart = start.adding(days: -(start.isoWeekday - 1))
            return weekStart.adding(days: step * 7 + rule.dayOfWeek - 1)

        case .monthly:
            guard (1...31).contains(rule.dayOfMonth) else { return nil }
            return clampedDate(
                YearMonth(containing: start).adding(months: step), day: rule.dayOfMonth)

        case .yearly:
            guard (1...31).contains(rule.dayOfMonth), (1...12).contains(rule.monthOfYear) else {
                return nil
            }
            return clampedDate(
                YearMonth(year: start.year + step, month: rule.monthOfYear), day: rule.dayOfMonth)
        }
    }

    /// The given day of month, or the month's last day when it is shorter (31 -> 30 Nov,
    /// 29 Feb -> 28 Feb in a non-leap year).
    private static func clampedDate(_ month: YearMonth, day: Int) -> CivilDate {
        CivilDate(
            year: month.year, month: month.month,
            day: min(day, CivilDate.daysInMonth(year: month.year, month: month.month)))
    }
}
