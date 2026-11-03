import Foundation

/// Free-plan limits (BUSINESS_RULES §7). The server enforces them on push; the client checks
/// first so the user is told before saving.
enum PlanLimits {
    static let maxFreeAccounts = 4
    static let maxFreeCustomCategories = 5

    /// Premium is trusted until `expires_at` plus this offline grace period.
    static let offlineTolerance: TimeInterval = 3 * 24 * 3600

    /// Reads the cached `meta.entitlement` JSON of `sync_state.entitlement`. Anything missing or
    /// unreadable counts as free.
    static func isPremium(entitlementJSON: String?, now: Date) -> Bool {
        guard let entitlementJSON, !entitlementJSON.isEmpty,
            let entitlement = try? JSONValue.parse(entitlementJSON),
            entitlement["premium"]?.boolValue == true
        else { return false }
        guard let expires = entitlement["expires_at"]?.stringValue else { return true }
        guard let expiry = TimestampFormat.parse(expires) else { return false }
        return now <= expiry.addingTimeInterval(offlineTolerance)
    }
}
