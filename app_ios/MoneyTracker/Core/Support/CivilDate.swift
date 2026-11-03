import Foundation

/// A calendar date without time or timezone. Encodes as "YYYY-MM-DD".
/// Mirrors `backend/internal/platform/civil`: out-of-range components are normalized.
struct CivilDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    enum ParseError: Error {
        case invalid(String)
    }

    /// Builds a date, normalizing out-of-range month or day values like Go's `time.Date`.
    init(year: Int, month: Int, day: Int) {
        let monthIndex = month - 1
        let normalizedYear = year + Self.floorDiv(monthIndex, 12)
        let normalizedMonth = Self.floorMod(monthIndex, 12) + 1
        self.init(daysSinceEpoch: Self.daysFromCivil(normalizedYear, normalizedMonth, 1) + day - 1)
    }

    /// Days since 1970-01-01.
    init(daysSinceEpoch days: Int) {
        let z = days + 719_468
        let era = Self.floorDiv(z, 146_097)
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        self.month = m
        self.day = d
    }

    /// Reads a strict `YYYY-MM-DD` string.
    init(parsing string: String) throws {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard string.utf8.count == 10, parts.count == 3,
            parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            (1...12).contains(month), day >= 1, day <= Self.daysInMonth(year: year, month: month)
        else {
            throw ParseError.invalid(string)
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar date of `date` in `timeZone`.
    init(_ date: Date, in timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year ?? 1970
        self.month = c.month ?? 1
        self.day = c.day ?? 1
    }

    var daysSinceEpoch: Int { Self.daysFromCivil(year, month, day) }

    /// ISO weekday: Monday = 1 ... Sunday = 7.
    var isoWeekday: Int {
        // 1970-01-01 was a Thursday (4).
        Self.floorMod(daysSinceEpoch + 3, 7) + 1
    }

    var description: String {
        let y = String(year)
        return String(repeating: "0", count: max(0, 4 - y.count)) + y
            + (month < 10 ? "-0" : "-") + String(month)
            + (day < 10 ? "-0" : "-") + String(day)
    }

    func adding(days: Int) -> CivilDate {
        CivilDate(daysSinceEpoch: daysSinceEpoch + days)
    }

    /// Days from `other` to `self` (negative when `self` is earlier).
    func days(since other: CivilDate) -> Int {
        daysSinceEpoch - other.daysSinceEpoch
    }

    var firstOfMonth: CivilDate { CivilDate(year: year, month: month, day: 1) }

    var lastOfMonth: CivilDate {
        CivilDate(year: year, month: month, day: Self.daysInMonth(year: year, month: month))
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        CivilDate(year: year, month: month + 1, day: 1).adding(days: -1).day
    }

    static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    // Howard Hinnant's days_from_civil.
    private static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDiv(y, 400)
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    private static func floorMod(_ a: Int, _ b: Int) -> Int {
        a - floorDiv(a, b) * b
    }
}

extension CivilDate: Codable {
    init(from decoder: any Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        try self.init(parsing: string)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
