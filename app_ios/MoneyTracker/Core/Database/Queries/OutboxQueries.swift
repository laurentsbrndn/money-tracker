import Foundation
import GRDB

extension OutboxRecord {
    var item: OutboxItem {
        OutboxItem(
            seq: seq ?? 0, entity: entity, recordId: recordId, op: op, updatedAt: updatedAt,
            batchId: batchId, attempts: attempts, nextAttemptAt: nextAttemptAt)
    }
}

extension Database {
    func outboxAll() throws -> [OutboxRecord] {
        try OutboxRecord.order(Column("seq")).fetchAll(self)
    }

    func outboxEntries(entity: String, recordId: String) throws -> [OutboxRecord] {
        try OutboxRecord.filter(Column("entity") == entity && Column("record_id") == recordId)
            .order(Column("seq")).fetchAll(self)
    }

    /// `recordKey`s of every record with an outbox entry, in flight or not (SYNC_PROTOCOL §9.4).
    func outboxRecordKeys() throws -> Set<String> {
        let rows = try Row.fetchAll(self, sql: "SELECT DISTINCT entity, record_id FROM outbox")
        return Set(rows.map { recordKey($0["entity"], $0["record_id"]) })
    }

    func outboxRemove(seq: Int64) throws {
        _ = try OutboxRecord.deleteOne(self, key: seq)
    }

    /// Overwrites a not-yet-sent entry (coalescing rule 6.3.1): clears attempts and backoff.
    func outboxOverwrite(seq: Int64, op: String, payload: String, updatedAt: Date) throws {
        try execute(
            sql: """
                UPDATE outbox SET op = ?, payload = ?, updated_at = ?, attempts = 0,
                    next_attempt_at = NULL, last_error = NULL WHERE seq = ?
                """,
            arguments: [op, payload, TimestampFormat.format(updatedAt), seq])
    }

    /// Marks entries as sent in the batch `batchId` (SYNC_PROTOCOL §5.2.1).
    func outboxMarkInFlight(seqs: [Int64], batchId: String) throws {
        try OutboxRecord.filter(seqs.contains(Column("seq"))).updateAll(
            self, Column("batch_id").set(to: batchId))
    }

    /// Back to "not sent", with the backoff of a retryable failure.
    func outboxScheduleRetry(seq: Int64, attempts: Int, nextAttemptAt: Date, lastError: String)
        throws
    {
        try execute(
            sql: """
                UPDATE outbox SET batch_id = NULL, attempts = ?, next_attempt_at = ?,
                    last_error = ? WHERE seq = ?
                """,
            arguments: [attempts, TimestampFormat.format(nextAttemptAt), lastError, seq])
    }

    /// The soonest `next_attempt_at` among entries that are waiting out a backoff.
    func outboxEarliestRetry() throws -> Date? {
        let text = try String.fetchOne(
            self,
            sql: """
                SELECT MIN(next_attempt_at) FROM outbox
                WHERE next_attempt_at IS NOT NULL AND batch_id IS NULL
                """)
        return text.flatMap(TimestampFormat.parse)
    }
}

extension AppDatabase {
    /// Number of outbox entries; drives the "Menunggu sync (n)" badge.
    func observePendingChangeCount() -> AsyncValueObservation<Int> {
        ValueObservation.tracking { try OutboxRecord.fetchCount($0) }.values(in: pool)
    }
}
