import Foundation

/// What to do with the outbox when a record is written locally (SYNC_PROTOCOL §6, step 3).
enum OutboxWriteDecision: Sendable, Equatable {
    /// Overwrite the not-yet-sent entry (rule 3.1).
    case replace(seq: Int64)
    /// Add a new entry (rule 3.3).
    case append
    /// A delete of a record the server never received (rule 3.2): remove the unsent entry (if
    /// any) and delete the local row for good.
    case drop(removeSeq: Int64?)
}

/// `existing` are the outbox entries of this one record. `serverVersion` is the local row's
/// `server_version` (nil when the server never confirmed it).
func decideOutboxWrite(existing: [OutboxItem], op: String, serverVersion: Int64?)
    -> OutboxWriteDecision
{
    var unsent: OutboxItem?
    var anyInFlight = false
    for item in existing {
        if item.inFlight {
            anyInFlight = true
        } else if unsent == nil || item.seq > unsent!.seq {
            unsent = item
        }
    }
    if op == "delete" && serverVersion == nil && !anyInFlight {
        return .drop(removeSeq: unsent?.seq)
    }
    if let unsent { return .replace(seq: unsent.seq) }
    return .append
}
