import Foundation
import GRDB

struct AccountRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord, PersistableRecord
{
    static let databaseTableName = "accounts"
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
    var name: String
    /// `bank`, `e_wallet`, `cash`, or `savings`.
    var type: String
    var providerKey: String?
    var currency: String
    /// May be negative.
    var openingBalance: Int64
    var openingDate: CivilDate
    var includeInTotal: Bool
    var sortOrder: Int
    var archivedAt: Date?
}
