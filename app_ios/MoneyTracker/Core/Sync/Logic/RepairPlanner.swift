import Foundation

/// Records whose local row must be re-fetched from the server because a normal pull can no
/// longer deliver them (SYNC_PROTOCOL §9.5, "stale yang tersangkut").
///
/// A pull skips a record while it has an outbox entry, yet the cursor still moves past it. If
/// that entry is then answered `stale`, the server row's `server_version` is at or below the
/// cursor and no later pull returns it. `cursor` is the local `pull_cursor` before this cycle's
/// pull. A stale answer without a `server_version` is repaired too, to be safe.
func staleRepairKeys(_ answered: [(OutboxItem, PushAction)], cursor: Int64) -> Set<String> {
    var keys = Set<String>()
    for (item, action) in answered {
        guard case .removeStale(let version) = action else { continue }
        if version == nil || version! <= cursor {
            keys.insert(recordKey(item.entity, item.recordId))
        }
    }
    return keys
}

/// The part of a from-the-start pull page to write: rows listed in `repairKeys` that have no
/// outbox entry now (same rule as a normal pull).
func planRepairPull(
    _ changes: [PullChangeItem], repairKeys: Set<String>, outboxKeys: Set<String>
) -> [PullChangeItem] {
    changes.filter {
        let key = recordKey($0.entity, $0.id)
        return repairKeys.contains(key) && !outboxKeys.contains(key)
    }
}
