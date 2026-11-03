import Foundation
import GRDB

/// Type-erased access to one synced table, by entity name. Everything the sync code needs to do
/// with a row without knowing its type: read it as wire JSON, change its sync bookkeeping, and
/// write a row delivered by the server.
protocol EntityStore: Sendable {
    var entity: String { get }
    func rowJSON(_ db: Database, id: String) throws -> JSONValue?
    func serverVersion(_ db: Database, id: String) throws -> Int64?
    func updatedAt(_ db: Database, id: String) throws -> Date?
    func deletedAt(_ db: Database, id: String) throws -> Date?
    /// Removes the row for good (SYNC_PROTOCOL §6.3.2).
    func deleteHard(_ db: Database, id: String) throws
    /// Soft delete: sets `deleted_at` and `updated_at`, `pending`.
    func markDeleted(_ db: Database, id: String, now: Date) throws
    /// Bumps `updated_at` and marks the row `pending` again.
    func touch(_ db: Database, id: String, now: Date) throws
    func markSynced(_ db: Database, id: String, serverVersion: Int64?) throws
    func markFailed(_ db: Database, id: String, error: String) throws
    /// Writes a row from the server as `synced`.
    func saveFromServer(_ db: Database, data: JSONValue, serverVersion: Int64) throws
}

struct RecordStore<R: SyncRecord>: EntityStore {
    var entity: String { R.entity }

    func rowJSON(_ db: Database, id: String) throws -> JSONValue? {
        try R.fetchOne(db, key: id)?.wireJSON
    }

    func serverVersion(_ db: Database, id: String) throws -> Int64? {
        try R.fetchOne(db, key: id)?.serverVersion
    }

    func updatedAt(_ db: Database, id: String) throws -> Date? {
        try R.fetchOne(db, key: id)?.updatedAt
    }

    func deletedAt(_ db: Database, id: String) throws -> Date? {
        try R.fetchOne(db, key: id)?.deletedAt
    }

    func deleteHard(_ db: Database, id: String) throws {
        _ = try R.deleteOne(db, key: id)
    }

    func markDeleted(_ db: Database, id: String, now: Date) throws {
        try update(db, id) {
            $0.deletedAt = now
            $0.updatedAt = now
            $0.syncStatus = "pending"
            $0.syncError = nil
        }
    }

    func touch(_ db: Database, id: String, now: Date) throws {
        try update(db, id) {
            $0.updatedAt = now
            $0.syncStatus = "pending"
            $0.syncError = nil
        }
    }

    func markSynced(_ db: Database, id: String, serverVersion: Int64?) throws {
        try update(db, id) {
            if let serverVersion { $0.serverVersion = serverVersion }
            $0.syncStatus = "synced"
            $0.syncError = nil
        }
    }

    func markFailed(_ db: Database, id: String, error: String) throws {
        try update(db, id) {
            $0.syncStatus = "failed"
            $0.syncError = error
        }
    }

    func saveFromServer(_ db: Database, data: JSONValue, serverVersion: Int64) throws {
        try R(wire: data, serverVersion: serverVersion).save(db)
    }

    private func update(_ db: Database, _ id: String, _ change: (inout R) -> Void) throws {
        guard var row = try R.fetchOne(db, key: id) else { return }
        change(&row)
        try row.update(db)
    }
}

/// The seven synced tables, found by entity name. An entity this client version does not know is
/// `nil`, not fatal (a newer server may send more).
struct EntityStores: Sendable {
    private let byEntity: [String: any EntityStore]

    init() {
        let stores: [any EntityStore] = [
            RecordStore<UserSettingsRecord>(), RecordStore<CategoryRecord>(),
            RecordStore<AccountRecord>(), RecordStore<BalanceSnapshotRecord>(),
            RecordStore<TransactionRecord>(), RecordStore<RecurringRuleRecord>(),
            RecordStore<BudgetGoalRecord>(),
        ]
        byEntity = Dictionary(uniqueKeysWithValues: stores.map { ($0.entity, $0) })
    }

    func maybeOf(_ entity: String) -> (any EntityStore)? { byEntity[entity] }

    func of(_ entity: String) -> any EntityStore {
        guard let store = byEntity[entity] else {
            preconditionFailure("Unknown sync entity \(entity)")
        }
        return store
    }
}
