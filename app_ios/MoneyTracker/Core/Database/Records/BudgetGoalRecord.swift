import Foundation
import GRDB

/// `id` is deterministic: UUIDv5 of the user id and the month (see SYNC_PROTOCOL §3).
struct BudgetGoalRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "budget_goals"
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
    /// Always the first day of the month.
    var effectiveMonth: CivilDate
    var needsPct: Int
    var wantsPct: Int
    var savingsPct: Int
    var plannedIncome: Int64?
}

extension BudgetGoalRecord: SyncRecord {
    static let entity = SyncEntities.budgetGoals
}
