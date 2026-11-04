/// Why a store operation could not be done, in terms the UI can explain.
enum BillingFailure: Sendable, Equatable {
    /// No RevenueCat key in this build (`REVENUECAT_IOS_KEY` is empty), or the SDK could not be
    /// configured.
    case unavailable
    /// The store or RevenueCat could not be reached.
    case network
    /// No subscription products are offered (not configured in the console, or not available in
    /// this country/account).
    case noProducts
    /// The product cannot be bought (not published, or not allowed here).
    case productUnavailable
    /// The store account cannot buy right now (parental controls, payments disabled).
    case notAllowed
    /// A purchase or restore is already running.
    case busy
    /// The server session cannot be linked to the store customer.
    case accountLink
    case unknown
}

/// Raised by the billing service for everything except a user cancel or a pending purchase,
/// which are normal outcomes.
struct BillingError: Error, Sendable, Equatable {
    let failure: BillingFailure
}

/// How a purchase ended when it did not fail.
enum PurchaseOutcome: Sendable, Equatable {
    /// The store took the payment. Premium is NOT granted yet: the server learns about it from
    /// the RevenueCat webhook.
    case purchased
    /// The user closed the store dialog.
    case cancelled
    /// The payment waits for approval (Ask to Buy); it completes later, outside the app.
    case pending
}
