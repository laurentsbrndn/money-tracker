import Foundation
import Synchronization

/// "Today" as a calendar date in the user's own timezone (BUSINESS_RULES §1), not the device's
/// and not UTC. The timezone is the IANA identifier saved in `user_settings`; `PreferencesStore`
/// keeps it up to date, so every screen and repository that calls `today()` follows a changed
/// setting. Until the first `user_settings` row has been pulled it is `defaultTimezone`, which is
/// also the server default (DATA_MODEL §2).
enum UserClock {
    static let defaultTimezone = "Asia/Jakarta"

    private static let current = Mutex(TimeZone(identifier: defaultTimezone) ?? .gmt)

    #if DEBUG
        private static let fixedToday = Mutex<CivilDate?>(nil)

        /// Previews only: pins "today" so the sample month always has the same numbers.
        static func pinTodayForPreviews(_ date: CivilDate) {
            fixedToday.withLock { $0 = date }
        }
    #endif

    /// Whether `identifier` is an IANA name the system knows.
    static func isValid(timezone identifier: String) -> Bool {
        TimeZone(identifier: identifier) != nil
    }

    /// The zone for `identifier`, or `defaultTimezone` when it is unknown.
    static func zone(for identifier: String) -> TimeZone {
        TimeZone(identifier: identifier) ?? TimeZone(identifier: defaultTimezone) ?? .gmt
    }

    /// Makes `identifier` the zone of `today()` from now on (unknown names fall back).
    static func configure(timezone identifier: String) {
        let resolved = zone(for: identifier)
        current.withLock { $0 = resolved }
    }

    static var timeZone: TimeZone { current.withLock { $0 } }

    /// The calendar date of `instant` in `zone`: port of `civilDateIn` / `Today`
    /// (`domainrules/period.go`).
    static func civilDate(of instant: Date, in zone: TimeZone) -> CivilDate {
        CivilDate(instant, in: zone)
    }

    /// Minutes since local midnight of `instant` in `zone`.
    static func minutesOfDay(of instant: Date, in zone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let c = calendar.dateComponents([.hour, .minute], from: instant)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func today(now: Date = Date()) -> CivilDate {
        #if DEBUG
            if let fixed = fixedToday.withLock({ $0 }) { return fixed }
        #endif
        return civilDate(of: now, in: timeZone)
    }
}
