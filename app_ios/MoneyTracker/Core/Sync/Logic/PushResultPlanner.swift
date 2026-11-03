import Foundation

/// What to do with one outbox entry after the server answered (SYNC_PROTOCOL §8.4).
enum PushAction: Sendable, Equatable {
    /// `applied`: remove the entry. The row is marked synced only if it has not changed since it
    /// was sent (see `rowUnchangedSinceSend`).
    case removeApplied(serverVersion: Int64?)
    /// `stale`: remove the entry; the row stays pending until a pull replaces it.
    /// `serverVersion` is the version of the row the server kept; nil if it did not say.
    case removeStale(serverVersion: Int64?)
    /// Retryable failure: keep the entry (no longer in flight) and back off.
    case retryLater(attempts: Int, nextAttemptAt: Date, message: String)
    /// Non-retryable failure: remove the entry and mark the row `failed`.
    case failTerminal(code: String, message: String)
}

func planPushResult(_ item: OutboxItem, result: PushResultInfo?, now: Date) -> PushAction {
    // The server did not answer for this entry; send it again later.
    guard let result else {
        return retry(item, now, "no_result", "Server tidak mengembalikan hasil")
    }
    switch result.status {
    case "applied":
        return .removeApplied(serverVersion: result.serverVersion)
    case "stale":
        return .removeStale(serverVersion: result.serverVersion)
    case "rejected":
        let code = result.errorCode ?? "unknown"
        let message = result.errorMessage ?? code
        return result.retryable
            ? retry(item, now, code, message) : .failTerminal(code: code, message: message)
    default:
        return retry(item, now, "unknown_status", result.status)
    }
}

/// A whole-request failure that is not worth an immediate retry (4xx other than 401): count it
/// against the entry like a retryable rejection.
func planBatchFailure(_ item: OutboxItem, now: Date, message: String) -> PushAction {
    retry(item, now, "request_failed", message)
}

private func retry(_ item: OutboxItem, _ now: Date, _ code: String, _ message: String)
    -> PushAction
{
    let attempts = item.attempts + 1
    if attempts >= maxEntryAttempts {
        return .failTerminal(code: code, message: message)
    }
    return .retryLater(
        attempts: attempts, nextAttemptAt: now.addingTimeInterval(backoff(for: attempts)),
        message: "\(code): \(message)")
}

/// Whether the local row still holds what was sent: `applied` may then mark it synced. A newer
/// local edit has a different `updated_at`.
func rowUnchangedSinceSend(rowUpdatedAt: Date?, sentUpdatedAt: Date) -> Bool {
    guard let rowUpdatedAt else { return false }
    return TimestampFormat.epochMillis(rowUpdatedAt) == TimestampFormat.epochMillis(sentUpdatedAt)
}
