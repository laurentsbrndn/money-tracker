import Foundation

/// The server's entitlement as cached from the last pull or from `GET /v1/me/entitlements`
/// (`sync_state.entitlement`), read for display and for the offline tolerance. The server is the
/// only source of premium (FRONTEND_IOS §4.4).
struct EntitlementInfo: Sendable, Equatable {
    /// What the server said when it was last reachable.
    var serverPremium: Bool
    /// Whether premium features are open now: the server said premium and `expires_at` plus the
    /// 3-day offline tolerance has not passed.
    var premium: Bool
    /// Nil for a user who is not premium (and for premium without an end).
    var expiresAt: Date?
    var willRenew: Bool
    var productID: String?
    var store: String?

    static let free = EntitlementInfo(
        serverPremium: false, premium: false, expiresAt: nil, willRenew: false, productID: nil,
        store: nil)

    /// Reads the cached JSON at `now`. Anything missing or unreadable is free.
    init(cache json: String?, now: Date) {
        guard let json, !json.isEmpty, let value = try? JSONValue.parse(json),
            value.objectValue != nil
        else {
            self = .free
            return
        }
        serverPremium = value["premium"]?.boolValue == true
        premium = PlanLimits.isPremium(entitlementJSON: json, now: now)
        expiresAt = value["expires_at"]?.stringValue.flatMap(TimestampFormat.parse)
        willRenew = value["will_renew"]?.boolValue == true
        productID = value["product_id"]?.stringValue
        store = value["store"]?.stringValue
    }

    init(
        serverPremium: Bool, premium: Bool, expiresAt: Date?, willRenew: Bool, productID: String?,
        store: String?
    ) {
        self.serverPremium = serverPremium
        self.premium = premium
        self.expiresAt = expiresAt
        self.willRenew = willRenew
        self.productID = productID
        self.store = store
    }

    /// Premium only through the offline tolerance: `expires_at` has passed but the app has not
    /// heard from the server since.
    func isInTolerance(now: Date) -> Bool {
        guard premium, let expiresAt else { return false }
        return now > expiresAt
    }
}
