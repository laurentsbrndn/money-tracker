import Observation

/// Lainnya → Preferensi (APP_FLOWS Flow 12): timezone, first weekday, theme. They live in the
/// synced `user_settings` row.
@Observable
@MainActor
final class PreferencesViewModel {
    var errorMessage: String?
    private let repository: UserSettingsRepository

    init(container: AppContainer) {
        repository = container.userSettings
    }

    func setTimezone(_ identifier: String) async {
        await run { try await self.repository.setTimezone(identifier) }
    }

    func setWeekStart(_ weekStart: Int) async {
        await run { try await self.repository.setWeekStart(weekStart) }
    }

    func setTheme(_ theme: String) async {
        await run { try await self.repository.setTheme(theme) }
    }

    private func run(_ action: () async throws -> Void) async {
        do { try await action() } catch { errorMessage = ErrorMessages.describe(error) }
    }
}
