import Foundation
import GRDB

struct CategoryRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord, PersistableRecord
{
    static let databaseTableName = "categories"
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
    /// `expense` or `income`.
    var type: String
    var name: String
    var icon: String
    /// `#RRGGBB`.
    var color: String
    /// `needs`, `wants`, or `savings`; required for expense, null for income.
    var defaultAllocation: String?
    var sortOrder: Int
    var isDefault: Bool
    var isHidden: Bool
    var archivedAt: Date?
}
