/// What the rest of the app may ask of the store (FRONTEND_IOS §4.4). It never answers "is the
/// user premium": that comes from the server's entitlement. `BillingService` implements it with
/// RevenueCat; previews use a fake.
protocol BillingProviding: Sendable {
    /// Whether this build has a RevenueCat key and the SDK is running.
    var isAvailable: Bool { get async }

    /// Starts the SDK, for `userID` when someone is signed in (so purchases never start under an
    /// anonymous id). Without a key nothing happens and `isAvailable` stays false.
    func configure(userID: String?) async

    /// Makes the store customer match the server user: `logIn(<user id>)` for a signed-in user,
    /// `logOut()` when nobody is.
    func syncUser(_ userID: String?) async

    /// The monthly and yearly packages of the current offering, yearly last.
    func loadPackages() async throws -> [PaywallPackage]

    /// Buys the package. The purchase only happens when the store customer is `userID`, so the
    /// webhook can credit the right account.
    func purchase(packageID: String, userID: String) async throws -> PurchaseOutcome

    /// Asks the store for the user's past purchases and hands them to RevenueCat. Premium still
    /// comes from the server afterwards.
    func restore(userID: String) async throws
}
