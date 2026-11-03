import Foundation
import Synchronization

/// "Today" as a calendar date. Fase 1 uses the device's timezone; Fase 2 switches to
/// `user_settings.timezone` (BUSINESS_RULES §1) behind this same function.
enum UserClock {
    #if DEBUG
        private static let fixedToday = Mutex<CivilDate?>(nil)

        /// Previews only: pins "today" so the sample month always has the same numbers.
        static func pinTodayForPreviews(_ date: CivilDate) {
            fixedToday.withLock { $0 = date }
        }
    #endif

    static func today(now: Date = Date()) -> CivilDate {
        #if DEBUG
            if let fixed = fixedToday.withLock({ $0 }) { return fixed }
        #endif
        return CivilDate(now, in: .current)
    }
}
