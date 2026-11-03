import Foundation
import GRDB

/// The user's `user_settings` row (DATA_MODEL §2), which syncs between devices. Device-only
/// preferences (PIN, biometrics, auto-lock) are not here; they live in `Core/Security`. Every
/// write goes through the `OutboxWriter`.
struct UserSettingsRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter

    func observe() -> AsyncValueObservation<UserSettingsRecord?> { database.observeUserSettings() }

    /// Rewrites the current row through `change`. Throws while the row has not been pulled yet
    /// (a new account's first sync).
    private func update(_ change: @escaping @Sendable (inout UserSettingsRecord) -> Void)
        async throws
    {
        try await writer.write { tx in
            guard
                var row = try UserSettingsRecord.filter(Column("deleted_at") == nil).fetchOne(tx.db)
            else { throw ValidationError.settingsMissing }
            change(&row)
            try tx.upsert(row)
        }
    }

    func setTimezone(_ timezone: String) async throws {
        guard UserClock.isValid(timezone: timezone) else { throw ValidationError.timezoneInvalid }
        try await update { $0.timezone = timezone }
    }

    /// `system`, `light`, or `dark`.
    func setTheme(_ theme: String) async throws { try await update { $0.theme = theme } }

    /// 1 = Monday, 7 = Sunday.
    func setWeekStart(_ weekStart: Int) async throws {
        try await update { $0.weekStart = weekStart }
    }

    func setHideAmounts(_ hide: Bool) async throws { try await update { $0.hideAmounts = hide } }

    /// `HH:MM` local time, or nil to turn the daily reminder off.
    func setDailyReminderTime(_ time: String?) async throws {
        if let time, NotificationPlan.parseReminderTime(time) == nil {
            throw ValidationError.reminderTimeInvalid
        }
        try await update { $0.dailyReminderTime = time }
    }

    func setReconcileReminder(enabled: Bool) async throws {
        try await update { $0.reconcileReminderEnabled = enabled }
    }

    func setBudgetAlert(enabled: Bool) async throws {
        try await update { $0.budgetAlertEnabled = enabled }
    }
}
