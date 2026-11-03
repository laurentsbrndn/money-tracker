import Foundation
import GRDB

struct RecurringRuleRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "recurring_rules"
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
    /// `income`, `expense`, or `transfer`.
    var type: String
    var amount: Int64
    var accountId: String
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var source: String?
    var note: String?
    /// `daily`, `weekly`, `monthly`, or `yearly`.
    var frequency: String
    var intervalCount: Int
    /// 1-7 (Monday-Sunday), for `weekly`.
    var dayOfWeek: Int?
    /// 1-31, for `monthly` and `yearly`.
    var dayOfMonth: Int?
    /// 1-12, for `yearly`.
    var monthOfYear: Int?
    var startDate: CivilDate
    var endDate: CivilDate?
    /// `auto` or `confirm`.
    var mode: String
    var isPaused: Bool
    var lastGeneratedDate: CivilDate?
}

extension RecurringRuleRecord: SyncRecord {
    static let entity = SyncEntities.recurringRules
}
