import Foundation
import GRDB

/// Applies one pulled page to the local database (SYNC_PROTOCOL §9.4), in one transaction
/// together with the new cursor.
struct PullApplier: Sendable {
    let database: AppDatabase
    let stores: EntityStores

    func currentCursor() async throws -> Int64 {
        try await database.pool.read { try Self.cursor($0) }
    }

    /// Returns how many rows were written.
    func apply(_ page: PullPage) async throws -> Int {
        try await database.pool.write { db in
            let plan = planPull(page.changes, outboxKeys: try db.outboxRecordKeys())
            var written = 0
            for change in plan.toApply {
                // An entity this client version does not know is skipped, not fatal.
                guard let store = stores.maybeOf(change.entity) else { continue }
                try store.saveFromServer(db, data: change.data, serverVersion: change.serverVersion)
                written += 1
            }
            let cursor = nextPullCursor(current: try Self.cursor(db), pageNext: page.nextCursor)
            try db.setSyncState(SyncStateKey.pullCursor, String(cursor))
            if let entitlement = page.entitlement {
                try db.setSyncState(SyncStateKey.entitlement, try entitlement.jsonString())
            }
            return written
        }
    }

    /// Applies the rows of a from-the-start page that are in `repairKeys` and have no outbox
    /// entry. Returns the keys written. The cursor is untouched.
    func applyRepair(_ page: PullPage, repairKeys: Set<String>) async throws -> Set<String> {
        try await database.pool.write { db in
            let todo = planRepairPull(
                page.changes, repairKeys: repairKeys, outboxKeys: try db.outboxRecordKeys())
            var done = Set<String>()
            for change in todo {
                guard let store = stores.maybeOf(change.entity) else { continue }
                try store.saveFromServer(db, data: change.data, serverVersion: change.serverVersion)
                done.insert(recordKey(change.entity, change.id))
            }
            return done
        }
    }

    private static func cursor(_ db: Database) throws -> Int64 {
        try db.syncState(SyncStateKey.pullCursor).flatMap { Int64($0) } ?? 0
    }
}
