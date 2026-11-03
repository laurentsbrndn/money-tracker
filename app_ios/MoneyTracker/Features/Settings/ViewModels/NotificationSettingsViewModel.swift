import Foundation
import Observation

/// Lainnya → Notifikasi (APP_FLOWS Flow 12): daily reminder and its time, reconcile reminder,
/// budget warnings. The permission is asked when the user turns a reminder on, not before.
@Observable
@MainActor
final class NotificationSettingsViewModel {
    /// The time the daily reminder gets when it is switched on.
    static let defaultReminderTime = "20:00"

    private(set) var permissionGranted = true
    private(set) var permissionUndetermined = false
    var errorMessage: String?

    private let service: NotificationService
    private let repository: UserSettingsRepository

    init(container: AppContainer) {
        service = container.notificationService
        repository = container.userSettings
    }

    /// Re-reads the system permission (also when coming back from the system settings).
    func refreshPermission() async {
        permissionGranted = await service.areEnabled()
        permissionUndetermined = await service.isUndetermined()
    }

    /// Asks for the permission if it is missing; used when a reminder is switched on.
    func ensurePermission() async {
        let enabled = await service.areEnabled()
        if !enabled, await service.isUndetermined() {
            await service.requestPermission()
        }
        await refreshPermission()
    }

    func openSystemSettings() { service.openSystemSettings() }

    func setDaily(enabled: Bool) async {
        await run {
            if enabled { await self.ensurePermission() }
            try await self.repository.setDailyReminderTime(
                enabled ? Self.defaultReminderTime : nil)
        }
    }

    func setDailyTime(_ time: String) async {
        await run { try await self.repository.setDailyReminderTime(time) }
    }

    func setReconcile(enabled: Bool) async {
        await run {
            if enabled { await self.ensurePermission() }
            try await self.repository.setReconcileReminder(enabled: enabled)
        }
    }

    func setBudgetAlert(enabled: Bool) async {
        await run {
            if enabled { await self.ensurePermission() }
            try await self.repository.setBudgetAlert(enabled: enabled)
        }
    }

    private func run(_ action: () async throws -> Void) async {
        do { try await action() } catch { errorMessage = ErrorMessages.describe(error) }
    }

    // MARK: - `HH:MM` <-> picker value

    /// A date whose UTC wall clock is `time`; the picker runs in UTC so no zone shifts it.
    static func date(from time: String) -> Date {
        let parsed = NotificationPlan.parseReminderTime(time) ?? (20, 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(
            from: DateComponents(
                year: 2000, month: 1, day: 1, hour: parsed.hour, minute: parsed.minute))
            ?? Date(timeIntervalSince1970: 0)
    }

    static func time(from date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 20, c.minute ?? 0)
    }
}
