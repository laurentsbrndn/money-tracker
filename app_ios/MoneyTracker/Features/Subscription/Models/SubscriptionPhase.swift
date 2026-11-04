/// Where a purchase or restore is.
enum SubscriptionPhase: Sendable, Equatable {
    case idle
    /// The store dialog or the restore is running.
    case purchasing
    /// The store took the payment; waiting for the server to report premium.
    case processing
    /// The server reports premium.
    case confirmed
    /// The server did not report premium within the time limit. The payment may still arrive;
    /// the user can check again.
    case timedOut
}
