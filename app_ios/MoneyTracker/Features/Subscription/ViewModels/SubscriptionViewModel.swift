import Foundation
import Observation

/// The paywall's actions: list packages, buy, restore, and wait for the server to confirm.
/// Premium is never taken from the store: after a purchase or a restore the server is asked
/// (`GET /v1/me/entitlements`) until it reports premium, because the RevenueCat webhook can be
/// late (FRONTEND_IOS §4.4).
///
/// Owned by `AppContainer`, so leaving the screen does not drop the wait for the server.
@Observable
@MainActor
final class SubscriptionViewModel {
    private(set) var packages: [PaywallPackage] = []
    private(set) var packagesLoading = false
    /// Why the packages could not be listed (nil while they can).
    private(set) var packagesFailure: BillingFailure?
    private(set) var phase: SubscriptionPhase = .idle
    private(set) var notice: SubscriptionNotice = .none

    /// A purchase, a restore, or the wait for the server is in progress.
    var busy: Bool { phase == .purchasing || phase == .processing }

    private let billing: any BillingProviding
    private let entitlements: EntitlementRepository
    private let session: SessionStore
    private let requestSync: @MainActor () -> Void
    /// A restore of nothing should not keep the user waiting for half a minute.
    private let restoreTimeout: TimeInterval = 15

    init(
        billing: any BillingProviding, entitlements: EntitlementRepository, session: SessionStore,
        requestSync: @escaping @MainActor () -> Void
    ) {
        self.billing = billing
        self.entitlements = entitlements
        self.session = session
        self.requestSync = requestSync
    }

    /// Starts a fresh visit to the paywall. A wait that is still running keeps its state.
    func open() async {
        if !busy {
            phase = .idle
            notice = .none
        }
        await loadPackages()
    }

    func loadPackages() async {
        guard await billing.isAvailable else {
            packagesFailure = .unavailable
            packagesLoading = false
            return
        }
        packagesLoading = true
        packagesFailure = nil
        do {
            packages = try await billing.loadPackages()
        } catch let error as BillingError {
            packagesFailure = error.failure
        } catch {
            packagesFailure = .unknown
        }
        packagesLoading = false
    }

    func buy(_ packageID: String) async {
        guard !busy, let userID = session.user?.id else { return }
        phase = .purchasing
        notice = .none
        do {
            switch try await billing.purchase(packageID: packageID, userID: userID) {
            case .purchased:
                await confirm()
            case .cancelled:
                phase = .idle
                notice = .cancelled
            case .pending:
                phase = .idle
                notice = .pending
            }
        } catch let error as BillingError {
            fail(error.failure)
        } catch {
            fail(.unknown)
        }
    }

    func restore() async {
        guard !busy, let userID = session.user?.id else { return }
        phase = .purchasing
        notice = .none
        do {
            try await billing.restore(userID: userID)
            await confirm(afterRestore: true)
        } catch let error as BillingError {
            fail(error.failure)
        } catch {
            fail(.unknown)
        }
    }

    /// "Periksa lagi" after a timeout: asks the server again for a while.
    func checkAgain() async {
        if !busy { await confirm() }
    }

    /// Best effort refresh of the cached entitlement (opening the subscription screen); failures
    /// are ignored, the cache stays as it is.
    func refreshStatus() async {
        _ = try? await entitlements.refresh()
    }

    private func confirm(afterRestore: Bool = false) async {
        phase = .processing
        let repository = entitlements
        let result = await pollUntilPremium(
            timeout: afterRestore ? restoreTimeout : entitlementPollTimeout,
            isPremium: {
                do {
                    return try await repository.refresh()
                } catch {
                    if case .api(let problem) = APIFailure(error),
                        problem.status == 401 || problem.status == 403
                    {
                        throw PollAbort()
                    }
                    throw error
                }
            })
        switch result.outcome {
        case .confirmed:
            phase = .confirmed
            // Changes the plan refused are re-sent by the billing coordinator; this also pulls
            // whatever the server did meanwhile.
            requestSync()
        case .timedOut:
            phase = afterRestore ? .idle : .timedOut
            notice = afterRestore ? .restoreNothing : .none
        case .aborted:
            phase = .idle
            notice = .sessionExpired
        }
    }

    private func fail(_ failure: BillingFailure) {
        phase = .idle
        notice = .failure(failure)
    }
}
