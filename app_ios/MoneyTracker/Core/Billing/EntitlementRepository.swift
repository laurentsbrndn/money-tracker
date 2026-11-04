import Foundation

/// Reads the entitlement from the server and caches it where a pull would
/// (`sync_state.entitlement`). It is the only online call about premium.
struct EntitlementRepository: Sendable {
    let database: AppDatabase
    let client: Client

    /// `GET /v1/me/entitlements`, stored for `EntitlementInfo`. Returns whether the server says
    /// premium. Throws the API error (offline, 401, ...).
    func refresh() async throws -> Bool {
        let entitlement = try await client.getEntitlements().ok.body.json
        var object: [String: JSONValue] = [
            "premium": .bool(entitlement.premium),
            "will_renew": .bool(entitlement.will_renew),
        ]
        object["expires_at"] = entitlement.expires_at.map { .string(TimestampFormat.format($0)) } ?? .null
        if let product = entitlement.product_id { object["product_id"] = .string(product) }
        if let store = entitlement.store { object["store"] = .string(store.rawValue) }
        try await database.setSyncState(
            SyncStateKey.entitlement, try JSONValue.object(object).jsonString())
        return entitlement.premium
    }
}
