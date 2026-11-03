import Foundation

/// "Today" as a calendar date. Fase 1 uses the device's timezone; Fase 2 switches to
/// `user_settings.timezone` (BUSINESS_RULES §1) behind this same function.
enum UserClock {
    static func today(now: Date = Date()) -> CivilDate {
        CivilDate(now, in: .current)
    }
}
