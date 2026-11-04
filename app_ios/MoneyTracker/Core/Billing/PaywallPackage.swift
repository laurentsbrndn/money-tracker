enum PaywallPeriod: Int, Sendable, Comparable {
    case monthly
    case yearly
    case other

    static func < (lhs: PaywallPeriod, rhs: PaywallPeriod) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// What the paywall shows of a subscription package. The store SDK's own types stay inside the
/// billing service.
struct PaywallPackage: Sendable, Equatable, Identifiable {
    /// RevenueCat package identifier, passed back to `purchase`.
    let id: String
    let period: PaywallPeriod
    /// The price as the store formats it (`Rp49.000,00`).
    let priceText: String
    /// A free trial applies to this package (for a user who is eligible).
    let hasTrial: Bool
    /// The store's product title, used when `period` is `.other`.
    let title: String
}
