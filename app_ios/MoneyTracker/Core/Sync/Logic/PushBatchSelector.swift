import Foundation

/// Entries chosen for one push request.
struct PushBatch: Sendable, Equatable {
    /// Used as the `Idempotency-Key`.
    var batchId: String
    var items: [OutboxItem]
    /// True when the batch was already sent before and is sent again unchanged.
    var isResend: Bool
}

let maxPushBatchSize = 100

/// Picks the next batch from `all` (SYNC_PROTOCOL §5.2.1 and §7).
///
/// An in-flight batch is re-sent first, exactly as it was. Otherwise up to `limit` due entries
/// (no backoff pending), oldest `seq` first, get a fresh id from `newBatchId`. Returns nil when
/// nothing is ready. The caller must persist the new `batch_id` before sending.
func selectPushBatch(
    _ all: [OutboxItem], now: Date, newBatchId: () -> String, limit: Int = maxPushBatchSize
) -> PushBatch? {
    let bySeq = all.sorted { $0.seq < $1.seq }

    if let flying = bySeq.first(where: { $0.batchId != nil }), let id = flying.batchId {
        return PushBatch(
            batchId: id, items: bySeq.filter { $0.batchId == id }, isResend: true)
    }

    var due: [OutboxItem] = []
    for item in bySeq {
        if item.nextAttemptAt == nil || item.nextAttemptAt! <= now {
            due.append(item)
            if due.count == limit { break }
        }
    }
    if due.isEmpty { return nil }
    return PushBatch(batchId: newBatchId(), items: due, isResend: false)
}
