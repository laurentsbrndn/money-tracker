import Foundation

extension YearMonth {
    enum ParseError: Error {
        case invalid(String)
    }

    /// Reads a strict `YYYY-MM` string.
    init(parsing string: String) throws {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard string.utf8.count == 7, parts.count == 2, parts[0].count == 4, parts[1].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month)
        else {
            throw ParseError.invalid(string)
        }
        self.init(year: year, month: month)
    }

    /// The month that contains `date`.
    init(containing date: CivilDate) {
        self.init(year: date.year, month: date.month)
    }

    /// Formatted as `YYYY-MM`.
    var description: String {
        let y = String(year)
        return String(repeating: "0", count: max(0, 4 - y.count)) + y
            + (month < 10 ? "-0" : "-") + String(month)
    }

    var first: CivilDate { CivilDate(year: year, month: month, day: 1) }

    var last: CivilDate { first.lastOfMonth }

    func contains(_ date: CivilDate) -> Bool {
        date.year == year && date.month == month
    }

    /// The month `n` months after this one (`n` may be negative).
    func adding(months n: Int) -> YearMonth {
        let index = year * 12 + month - 1 + n
        var y = index / 12
        var m = index % 12
        if m < 0 {
            m += 12
            y -= 1
        }
        return YearMonth(year: y, month: m + 1)
    }
}

extension DomainRules {
    enum PeriodError: Error {
        case unknownTimezone(String)
    }

    /// "Today" in the user's timezone (§1).
    static func today(now: Date, timezone: String) throws -> CivilDate {
        guard let zone = TimeZone(identifier: timezone) else {
            throw PeriodError.unknownTimezone(timezone)
        }
        return CivilDate(now, in: zone)
    }
}
