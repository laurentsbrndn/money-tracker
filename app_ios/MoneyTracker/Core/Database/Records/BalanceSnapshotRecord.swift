import Foundation
import GRDB

struct BalanceSnapshotRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "balance_snapshots"
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
    var accountId: String
    var snapshotDate: CivilDate
    var amount: Int64
    var note: String?
}
