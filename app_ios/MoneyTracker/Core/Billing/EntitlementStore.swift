import Foundation

/// Whether the free-plan limits are lifted, from the entitlement cached by the last pull.
/// Offline tolerance is applied (`PlanLimits.offlineTolerance`). Fase 3 extends this with
/// purchases; here it only reads the cache.
struct EntitlementStore: Sendable {
    let database: AppDatabase

    func isPremium() async -> Bool {
        let json = try? await database.syncState(SyncStateKey.entitlement)
        return PlanLimits.isPremium(entitlementJSON: json, now: Date())
    }
}
