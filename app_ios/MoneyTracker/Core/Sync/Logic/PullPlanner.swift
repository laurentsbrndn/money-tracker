import Foundation

/// Which pulled changes to write (SYNC_PROTOCOL §9.4).
struct PullPlan: Sendable, Equatable {
    var toApply: [PullChangeItem]
    /// Records with a local outbox entry: the local change wins until it has been pushed, and
    /// the server decides by last-write-wins.
    var skipped: [PullChangeItem]
}

/// `outboxKeys` holds `recordKey`s of every record that has an outbox entry, in flight or not.
/// The deciding factor is the entry, not `sync_status`.
func planPull(_ changes: [PullChangeItem], outboxKeys: Set<String>) -> PullPlan {
    var plan = PullPlan(toApply: [], skipped: [])
    for change in changes {
        if outboxKeys.contains(recordKey(change.entity, change.id)) {
            plan.skipped.append(change)
        } else {
            plan.toApply.append(change)
        }
    }
    return plan
}

/// The cursor never moves backwards.
func nextPullCursor(current: Int64, pageNext: Int64) -> Int64 {
    pageNext > current ? pageNext : current
}
