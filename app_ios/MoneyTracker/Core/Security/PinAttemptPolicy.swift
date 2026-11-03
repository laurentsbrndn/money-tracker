import Foundation

/// How long a wrong-PIN streak locks the PIN pad (growing delays). The `freeAttempts`-th
/// consecutive wrong PIN is the first to lock the pad; every further wrong try waits longer. The
/// counter only resets on a correct PIN, so waiting out a delay does not give a fresh set of
/// attempts.
enum PinAttemptPolicy {
    static let freeAttempts = 5

    private static let delays: [TimeInterval] = [30, 60, 5 * 60, 15 * 60, 30 * 60]

    /// The delay to impose after the `failures`-th consecutive wrong PIN; nil for the first
    /// `freeAttempts - 1` wrong tries.
    static func lockout(afterFailures failures: Int) -> TimeInterval? {
        guard failures >= freeAttempts else { return nil }
        let index = failures - freeAttempts
        return delays[min(index, delays.count - 1)]
    }

    /// Whole seconds left until `lockedUntil`, 0 when it has passed or is unset.
    static func secondsLeft(until lockedUntil: Date?, now: Date) -> Int {
        guard let lockedUntil, lockedUntil > now else { return 0 }
        return Int(lockedUntil.timeIntervalSince(now).rounded(.up))
    }
}
