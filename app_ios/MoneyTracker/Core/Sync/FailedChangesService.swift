import Foundation

/// The two ways out of "Perlu perhatian" (SYNC_PROTOCOL §8.4): send the stored change again
/// (after the user fixed the cause), or throw it away and take the server's version.
struct FailedChangesService: Sendable {
    let database: AppDatabase
    let stores: EntityStores
    let writer: OutboxWriter
    let remote: SyncRemote

    /// Queues the record again with a fresh `updated_at`.
    func retry(_ change: FailedChange) async throws {
        try await writer.write { tx in
            try tx.requeue(entity: change.entity, id: change.recordId)
        }
    }

    /// Replaces the local row with the server's, found by a full pull from the start; if the
    /// server has no such row the local one is removed. Does nothing if the record has been
    /// changed again since (it has an outbox entry then).
    func discard(_ change: FailedChange) async throws {
        let queued = try await database.pool.read {
            try $0.outboxEntries(entity: change.entity, recordId: change.recordId)
        }
        guard queued.isEmpty else { return }
        let store = stores.of(change.entity)
        var cursor: Int64 = 0
        while true {
            let page = try await remote.pull(since: cursor, limit: 1000)
            if let match = page.changes.first(where: {
                $0.entity == change.entity && $0.id == change.recordId
            }) {
                try await database.pool.write {
                    try store.saveFromServer(
                        $0, data: match.data, serverVersion: match.serverVersion)
                }
                return
            }
            if !page.hasMore || page.nextCursor <= cursor { break }
            cursor = page.nextCursor
        }
        try await database.pool.write { try store.deleteHard($0, id: change.recordId) }
    }
}
