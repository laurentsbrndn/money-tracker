import Foundation

/// Entries that failed retryably this many times become non-retryable (SYNC_PROTOCOL §8.4).
let maxEntryAttempts = 10

/// Delay after the `attempts`-th consecutive retryable failure (1-based):
/// 5 s, 15 s, 1 m, 5 m, then 15 m (SYNC_PROTOCOL §7).
func backoff(for attempts: Int) -> TimeInterval {
    let steps: [TimeInterval] = [5, 15, 60, 300]
    if attempts < 1 { return 0 }
    return attempts <= steps.count ? steps[attempts - 1] : 900
}
