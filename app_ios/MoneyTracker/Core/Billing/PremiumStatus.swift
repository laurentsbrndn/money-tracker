import Foundation
import Observation

/// What the UI reads to know whether premium is on: the entitlement the server reported (last
/// pull or `GET /v1/me/entitlements`), with the offline tolerance applied. The store SDK never
/// feeds this (FRONTEND_IOS §4.4). Observed for as long as the app lives; an observation that
/// ends (the database was wiped on logout) restarts.
@Observable
@MainActor
final class PremiumStatus {
    private(set) var info: EntitlementInfo = .free
    /// The cache was read at least once, so "free" below is a fact and not "not loaded yet".
    private(set) var loaded = false

    var isPremium: Bool { info.premium }

    /// Called when premium turns on (a purchase, a restore, a pull, another device).
    var onBecamePremium: (() -> Void)?

    private let database: AppDatabase
    private var task: Task<Void, Never>?

    init(database: AppDatabase) {
        self.database = database
    }

    func start() {
        guard task == nil else { return }
        let database = self.database
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    for try await flags in database.observeSyncState() {
                        self?.apply(flags[SyncStateKey.entitlement])
                    }
                } catch {}
                self?.apply(nil)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Reads the cache and the clock again, for when the app comes back to the foreground: the
    /// 3-day tolerance can run out without any database change.
    func refresh() async {
        let json = try? await database.syncState(SyncStateKey.entitlement)
        apply(json)
    }

    private func apply(_ json: String?) {
        let was = info.premium
        info = EntitlementInfo(cache: json, now: Date())
        loaded = true
        if info.premium && !was { onBecamePremium?() }
    }

    #if DEBUG
        /// Previews only: a fixed state.
        func applyPreview(_ info: EntitlementInfo) {
            self.info = info
            loaded = true
        }
    #endif
}
