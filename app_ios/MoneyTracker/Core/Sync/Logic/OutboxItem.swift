import Foundation

/// The part of an outbox row the pure sync rules need. Database access lives elsewhere so
/// these rules can be checked without GRDB or the network.
struct OutboxItem: Sendable, Equatable {
    var seq: Int64
    var entity: String
    var recordId: String
    /// `upsert` or `delete`.
    var op: String
    var updatedAt: Date
    /// Non-nil while the entry is in flight (SYNC_PROTOCOL §5.2.1).
    var batchId: String?
    var attempts: Int = 0
    var nextAttemptAt: Date?

    var inFlight: Bool { batchId != nil }
}

func recordKey(_ entity: String, _ recordId: String) -> String { "\(entity):\(recordId)" }
