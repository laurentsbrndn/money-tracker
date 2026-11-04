/// A one-line result shown on the paywall.
enum SubscriptionNotice: Sendable, Equatable {
    case none
    case cancelled
    case pending
    case restoreNothing
    case sessionExpired
    case failure(BillingFailure)
}
