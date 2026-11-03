import Observation

/// Preferences that every screen reads, taken from the synced `user_settings` row.
/// `hide_amounts` turns every nominal into `Rp •••••` (FRONTEND_IOS §4.6).
@Observable
@MainActor
final class PreferencesStore {
    private(set) var settings: UserSettingsRecord?

    private let database: AppDatabase
    private var task: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
    }

    var hideAmounts: Bool { settings?.hideAmounts ?? false }

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
