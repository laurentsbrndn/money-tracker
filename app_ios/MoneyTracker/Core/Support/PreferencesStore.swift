import Observation
import SwiftUI

/// Preferences that every screen reads, taken from the synced `user_settings` row.
/// `hide_amounts` turns every nominal into `Rp •••••` (FRONTEND_IOS §4.6). The row's timezone
/// is handed to `UserClock`, so "today" and month boundaries follow the setting.
@Observable
@MainActor
final class PreferencesStore {
    private(set) var settings: UserSettingsRecord? {
        didSet { UserClock.configure(timezone: settings?.timezone ?? UserClock.defaultTimezone) }
    }

    private let database: AppDatabase
    private var task: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
    }

    var hideAmounts: Bool { settings?.hideAmounts ?? false }

    /// The timezone identifier in force ("Asia/Jakarta" until the first pull).
    var timezone: String { settings?.timezone ?? UserClock.defaultTimezone }

    /// `nil` follows the system.
    var colorScheme: ColorScheme? {
        switch settings?.theme {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    /// Calendar for date pickers: first weekday from `week_start` (1 = Monday ... 7 = Sunday).
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "id_ID")
        calendar.firstWeekday = ((settings?.weekStart ?? 1) % 7) + 1
        return calendar
    }

    func start() {
        guard task == nil else { return }
        let database = self.database
        task = Task { [weak self] in
            while !Task.isCancelled {
                await forEachValue(database.observeUserSettings()) { self?.settings = $0 }
                self?.settings = nil
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
