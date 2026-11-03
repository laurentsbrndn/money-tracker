import Foundation
import GRDB

/// Applies the server's answer to a push to the local database (SYNC_PROTOCOL §8.4), in one
/// transaction.
struct PushApplier: Sendable {
    let database: AppDatabase
    let stores: EntityStores

    /// Returns the records that need a repair pull (see `staleRepairKeys`); `cursor` is the local
    /// pull cursor before this cycle's pull.
    func apply(batch: PushBatch, results: [PushResultInfo], now: Date, cursor: Int64) async throws
        -> Set<String>
    {
        let byRecord = Dictionary(
            results.map { (recordKey($0.entity, $0.id), $0) },
            uniquingKeysWith: { first, _ in first })
        return try await database.pool.write { db in
            var answered: [(OutboxItem, PushAction)] = []
            for item in batch.items {
                let action = planPushResult(
                    item, result: byRecord[recordKey(item.entity, item.recordId)], now: now)
                try applyAction(db, item, action)
                answered.append((item, action))
            }
            return staleRepairKeys(answered, cursor: cursor)
        }
    }

    /// A whole-request failure that counts against the entries (4xx other than 401): they leave
    /// "in flight" and back off.
    func applyBatchFailure(batch: PushBatch, message: String, now: Date) async throws {
        try await database.pool.write { db in
            for item in batch.items {
                try applyAction(db, item, planBatchFailure(item, now: now, message: message))
            }
        }
    }

    private func applyAction(_ db: Database, _ item: OutboxItem, _ action: PushAction) throws {
        let store = stores.maybeOf(item.entity)
        let unchanged = try store.map {
            rowUnchangedSinceSend(
                rowUpdatedAt: try $0.updatedAt(db, id: item.recordId), sentUpdatedAt: item.updatedAt
            )
        }
        switch action {
        case .removeApplied(let serverVersion):
            try db.outboxRemove(seq: item.seq)
            if let store, unchanged == true {
                try store.markSynced(db, id: item.recordId, serverVersion: serverVersion)
            }
        case .removeStale:
            try db.outboxRemove(seq: item.seq)
        case .retryLater(let attempts, let nextAttemptAt, let message):
            try db.outboxScheduleRetry(
                seq: item.seq, attempts: attempts, nextAttemptAt: nextAttemptAt, lastError: message)
        case .failTerminal(let code, let message):
            try db.outboxRemove(seq: item.seq)
            if let store, unchanged == true {
                try store.markFailed(db, id: item.recordId, error: "\(code): \(message)")
            }
        }
    }
}
