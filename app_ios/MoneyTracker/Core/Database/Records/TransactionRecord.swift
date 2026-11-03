import Foundation
import GRDB

struct TransactionRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "transactions"
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
    /// `income`, `expense`, `transfer`, or `adjustment`.
    var type: String
    /// `posted` or `pending_confirmation`.
    var status: String
    var transactionDate: CivilDate
    /// Positive, except for `adjustment` which is signed and non-zero.
    var amount: Int64
    var currency: String
    var accountId: String
    var toAccountId: String?
    var categoryId: String?
    /// `needs`, `wants`, or `savings`; only for expense.
    var allocation: String?
    var source: String?
    var note: String?
    var linkedTransactionId: String?
    var recurringRuleId: String?
}

extension TransactionRecord: SyncRecord {
    static let entity = SyncEntities.transactions
}
