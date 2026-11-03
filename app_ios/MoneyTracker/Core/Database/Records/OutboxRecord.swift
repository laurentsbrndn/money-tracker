import Foundation
import GRDB

struct OutboxRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    MutablePersistableRecord
{
    static let databaseTableName = "outbox"
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase

    static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .utcMillis
    }

    static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .utcMillis
    }

    /// Send order; nil until inserted.
    var seq: Int64?
    var entity: String
    var recordId: String
    /// `upsert` or `delete`.
    var op: String
    /// Whole row as JSON for `upsert`; empty for `delete`.
    var payload: String
    var updatedAt: Date
    /// Non-nil while the entry is in flight; also the `Idempotency-Key` of its batch.
    var batchId: String?
    var attempts: Int
    var nextAttemptAt: Date?
    var lastError: String?
    var createdAt: Date

    var id: Int64? { seq }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        seq = inserted.rowID
    }
}
