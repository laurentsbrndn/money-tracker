import GRDB

/// Key-value store: `device_id`, `pull_cursor`, `last_sync_at`, `entitlement`.
struct SyncStateRecord: Codable, Identifiable, Hashable, Sendable, FetchableRecord,
    PersistableRecord
{
    static let databaseTableName = "sync_state"

    var key: String
    var value: String

    var id: String { key }
}
