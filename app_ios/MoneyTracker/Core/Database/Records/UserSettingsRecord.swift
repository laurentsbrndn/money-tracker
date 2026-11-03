import Foundation
import GRDB

struct UserSettingsRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "user_settings"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .utcMillis
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .utcMillis
    }

    var id: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var serverVersion: Int64?
    var syncStatus: String
    /// `code: message` from the server when `syncStatus` is `failed`.
    var syncError: String?
    var timezone: String
    var currency: String
    /// 1 = Monday, 7 = Sunday.
    var weekStart: Int
    /// `system`, `light`, or `dark`.
    var theme: String
    /// `HH:MM` local time.
    var dailyReminderTime: String?
    var reconcileReminderEnabled: Bool
    var budgetAlertEnabled: Bool
    var hideAmounts: Bool
}

extension UserSettingsRecord: SyncRecord {
    static let entity = SyncEntities.userSettings
}
