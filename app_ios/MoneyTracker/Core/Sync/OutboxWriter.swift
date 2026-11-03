import Foundation
import GRDB

/// Writes data rows and their outbox entries in one local transaction (SYNC_PROTOCOL §6). Every
/// data write in the app goes through here, and a sync is requested after the transaction
/// commits.
struct OutboxWriter: Sendable {
    let database: AppDatabase
    let stores: EntityStores
    let onCommitted: @Sendable () -> Void

    /// Runs `body` in one transaction. All writes inside share `OutboxTx.now`, so a new record
    /// has `created_at == updated_at`.
    @discardableResult
    func write<T: Sendable>(_ body: @Sendable @escaping (OutboxTx) throws -> T) async throws -> T {
        let stores = self.stores
        let result = try await database.pool.write { db in
            try body(
                OutboxTx(db: db, stores: stores, now: TimestampFormat.truncatedToMillis(Date())))
        }
        onCommitted()
        return result
    }
}

/// The writes of one `OutboxWriter.write` call. Used synchronously inside the transaction.
struct OutboxTx {
    let db: Database
    let stores: EntityStores

    /// UTC, whole milliseconds. Use it for `created_at` of new rows.
    let now: Date

    /// Saves the whole `record` as `pending` with `updated_at = now`, and queues an `upsert`.
    /// The `server_version` of an existing row is kept.
    func upsert<R: SyncRecord>(_ record: R) throws {
        var row = record
        row.updatedAt = now
        row.syncStatus = "pending"
        row.syncError = nil
        if let existing = try R.fetchOne(db, key: row.id), let version = existing.serverVersion {
            row.serverVersion = version
        }
        try row.save(db)
        try enqueue(
            entity: R.entity, id: row.id, op: "upsert", payload: try row.wireJSON.jsonString(),
            serverVersion: row.serverVersion)
    }

    /// Deletes the record: a tombstone plus a queued `delete`, or, when the server never saw it,
    /// the row simply disappears (SYNC_PROTOCOL §6.3.2).
    func delete<R: SyncRecord>(_ type: R.Type, id: String) throws {
        try delete(entity: R.entity, id: id)
    }

    func delete(entity: String, id: String) throws {
        let store = stores.of(entity)
        guard try store.updatedAt(db, id: id) != nil else { return }
        let serverVersion = try store.serverVersion(db, id: id)
        let decision = decideOutboxWrite(
            existing: try existing(entity, id), op: "delete", serverVersion: serverVersion)
        if case .drop(let seq) = decision {
            if let seq { try db.outboxRemove(seq: seq) }
            try store.deleteHard(db, id: id)
            return
        }
        try store.markDeleted(db, id: id, now: now)
        try apply(decision, entity: entity, id: id, op: "delete", payload: "")
    }

    /// Queues the stored row again after a refused push (SYNC_PROTOCOL §8.4, "memperbaiki"): a
    /// live row as `upsert`, a tombstone as `delete`.
    func requeue(entity: String, id: String) throws {
        let store = stores.of(entity)
        guard let json = try store.rowJSON(db, id: id) else { return }
        try store.touch(db, id: id, now: now)
        let serverVersion = try store.serverVersion(db, id: id)
        if json["deleted_at"]?.isNull == false {
            try enqueue(
                entity: entity, id: id, op: "delete", payload: "", serverVersion: serverVersion)
        } else if let fresh = try store.rowJSON(db, id: id) {
            try enqueue(
                entity: entity, id: id, op: "upsert", payload: try fresh.jsonString(),
                serverVersion: serverVersion)
        }
    }

    private func existing(_ entity: String, _ id: String) throws -> [OutboxItem] {
        try db.outboxEntries(entity: entity, recordId: id).map(\.item)
    }

    private func enqueue(
        entity: String, id: String, op: String, payload: String, serverVersion: Int64?
    ) throws {
        let decision = decideOutboxWrite(
            existing: try existing(entity, id), op: op, serverVersion: serverVersion)
        try apply(decision, entity: entity, id: id, op: op, payload: payload)
    }

    private func apply(
        _ decision: OutboxWriteDecision, entity: String, id: String, op: String, payload: String
    ) throws {
        switch decision {
        case .replace(let seq):
            try db.outboxOverwrite(seq: seq, op: op, payload: payload, updatedAt: now)
        case .append:
            var entry = OutboxRecord(
                seq: nil, entity: entity, recordId: id, op: op, payload: payload, updatedAt: now,
                batchId: nil, attempts: 0, nextAttemptAt: nil, lastError: nil, createdAt: now)
            try entry.insert(db)
        case .drop:
            break
        }
    }
}
