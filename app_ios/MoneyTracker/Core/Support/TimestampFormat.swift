import Foundation

/// RFC 3339 UTC timestamps with exactly three millisecond digits and a `Z` suffix
/// (SYNC_PROTOCOL §4), e.g. "2026-11-02T14:05:00.123Z". Foundation-only so the sync rules
/// that depend on it can be checked outside the app.
enum TimestampFormat {
    private static let millisPerDay: Int64 = 86_400_000

    /// Whole milliseconds since the epoch, truncated (never rounded up).
    static func epochMillis(_ date: Date) -> Int64 {
        // The small epsilon absorbs binary floating point error, e.g. 1.234 * 1000 = 1233.999….
        Int64((date.timeIntervalSince1970 * 1000 + 0.01).rounded(.down))
    }

    static func date(epochMillis: Int64) -> Date {
        Date(timeIntervalSince1970: Double(epochMillis) / 1000)
    }

    static func truncatedToMillis(_ date: Date) -> Date {
        self.date(epochMillis: epochMillis(date))
    }

    static func format(_ date: Date) -> String {
        let millis = epochMillis(date)
        let days = floorDiv(millis, millisPerDay)
        let inDay = Int(millis - days * millisPerDay)
        let civil = CivilDate(daysSinceEpoch: Int(days))
        let hour = inDay / 3_600_000
        let minute = inDay / 60_000 % 60
        let second = inDay / 1000 % 60
        let milli = inDay % 1000
        return "\(civil)T\(pad(hour, 2)):\(pad(minute, 2)):\(pad(second, 2)).\(pad(milli, 3))Z"
    }

    /// Reads RFC 3339 with any fraction length and any UTC offset. Extra fraction digits are
    /// truncated, like the server does. Returns nil for anything malformed.
    static func parse(_ text: String) -> Date? {
        let bytes = Array(text.utf8)
        guard bytes.count >= 20, bytes[4] == 0x2D, bytes[7] == 0x2D,
            bytes[10] == 0x54 || bytes[10] == 0x74, bytes[13] == 0x3A, bytes[16] == 0x3A,
            let year = number(bytes, 0, 4), let month = number(bytes, 5, 2),
            let day = number(bytes, 8, 2), let hour = number(bytes, 11, 2),
            let minute = number(bytes, 14, 2), let second = number(bytes, 17, 2),
            (1...12).contains(month), day >= 1,
            day <= CivilDate.daysInMonth(year: year, month: month),
            hour < 24, minute < 60, second < 61
        else { return nil }

        var index = 19
        var milli = 0
        if bytes[index] == 0x2E {
            index += 1
            var digits = 0
            while index < bytes.count, bytes[index] >= 0x30, bytes[index] <= 0x39 {
                if digits < 3 { milli = milli * 10 + Int(bytes[index] - 0x30) }
                digits += 1
                index += 1
            }
            guard digits > 0 else { return nil }
            if digits < 3 { for _ in digits..<3 { milli *= 10 } }
        }
        guard index < bytes.count else { return nil }

        var offsetMinutes = 0
        switch bytes[index] {
        case 0x5A, 0x7A:
            guard index == bytes.count - 1 else { return nil }
        case 0x2B, 0x2D:
            guard bytes.count - index == 6, bytes[index + 3] == 0x3A,
                let offsetHour = number(bytes, index + 1, 2),
                let offsetMinute = number(bytes, index + 4, 2)
            else { return nil }
            offsetMinutes = (offsetHour * 60 + offsetMinute) * (bytes[index] == 0x2D ? -1 : 1)
        default:
            return nil
        }

        let days = Int64(CivilDate(year: year, month: month, day: day).daysSinceEpoch)
        let local = days * millisPerDay + Int64(((hour * 60 + minute) * 60 + second) * 1000 + milli)
        return date(epochMillis: local - Int64(offsetMinutes) * 60_000)
    }

    private static func number(_ bytes: [UInt8], _ start: Int, _ length: Int) -> Int? {
        guard start + length <= bytes.count else { return nil }
        var value = 0
        for i in start..<(start + length) {
            guard bytes[i] >= 0x30, bytes[i] <= 0x39 else { return nil }
            value = value * 10 + Int(bytes[i] - 0x30)
        }
        return value
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: max(0, width - text.count)) + text
    }

    private static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
}
