import Foundation

/// How the polling after a purchase or a restore ended.
enum PollOutcome: Sendable, Equatable {
    /// The server reports premium.
    case confirmed
    /// The deadline passed without the server reporting premium. The purchase may still arrive
    /// (the webhook can be late): the next sync picks it up.
    case timedOut
    /// A failure that polling again cannot fix (for example an expired login).
    case aborted
}

struct PollResult: Sendable {
    var outcome: PollOutcome
    var attempts: Int
}

/// Thrown by the check passed to `pollUntilPremium` when polling must stop.
struct PollAbort: Error {}

/// Overall limit of the polling after a purchase.
let entitlementPollTimeout: TimeInterval = 30

/// Pauses between attempts: 1, 2, 3, 4 s, then 5 s until the deadline (same as Flutter).
let entitlementPollDelays: [TimeInterval] = [1, 2, 3, 4, 5]

/// Asks the server, again and again, until it reports premium or `timeout` has passed.
/// RevenueCat tells the server about a purchase through a webhook that can be late, so premium
/// is never taken from the store SDK (FRONTEND_IOS §4.4); this waits for the server instead.
///
/// `isPremium` returns the server's answer. A thrown `PollAbort` ends the polling at once; any
/// other error (offline, 5xx) counts as "not yet" and is retried. `now` and `wait` are injected
/// so the schedule can be run without real time.
func pollUntilPremium(
    timeout: TimeInterval = entitlementPollTimeout,
    delays: [TimeInterval] = entitlementPollDelays,
    now: @Sendable () -> Date = { Date() },
    wait: @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
    isPremium: @Sendable () async throws -> Bool
) async -> PollResult {
    let deadline = now().addingTimeInterval(timeout)
    var attempts = 0
    while true {
        attempts += 1
        do {
            if try await isPremium() { return PollResult(outcome: .confirmed, attempts: attempts) }
        } catch is PollAbort {
            return PollResult(outcome: .aborted, attempts: attempts)
        } catch {
            // Offline or a server error: not yet, try again.
        }
        if Task.isCancelled { return PollResult(outcome: .aborted, attempts: attempts) }
        let delay = delays[min(max(attempts - 1, 0), delays.count - 1)]
        if now().addingTimeInterval(delay) > deadline {
            return PollResult(outcome: .timedOut, attempts: attempts)
        }
        await wait(delay)
    }
}
