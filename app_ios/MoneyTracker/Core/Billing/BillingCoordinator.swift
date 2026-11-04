import Foundation

/// Error codes of a refused push that only a premium plan can fix.
private let premiumRejections = ["plan_limit", "premium_required"]

/// Keeps the store customer equal to the signed-in server user (`logIn` after a login or
/// registration, `logOut` after a logout or account switch), and re-sends the changes the plan
/// refused as soon as the server reports premium (FRONTEND_IOS §4.4). It also covers a purchase
/// made on another device.
@MainActor
final class BillingCoordinator {
    private let billing: any BillingProviding
    private let session: SessionStore
    private let premium: PremiumStatus
    private let database: AppDatabase
    private let failedChanges: FailedChangesService
    private var configuration: Task<Void, Never>?

    init(
        billing: any BillingProviding, session: SessionStore, premium: PremiumStatus,
        database: AppDatabase, failedChanges: FailedChangesService
    ) {
        self.billing = billing
        self.session = session
        self.premium = premium
        self.database = database
        self.failedChanges = failedChanges
    }

    func start() {
        guard configuration == nil else { return }
        let billing = self.billing
        // The SDK starts under the signed-in user (no anonymous id in between). Later calls wait
        // for it.
        let userID = session.user?.id
        let configure = Task { await billing.configure(userID: userID) }
        configuration = configure
        session.onUserChanged = { id in
            Task {
                await configure.value
                await billing.syncUser(id)
            }
        }
        premium.onBecamePremium = { [weak self] in
            Task { await self?.retryRejected() }
        }
    }

    private func retryRejected() async {
        let changes =
            (try? await database.pool.read { try FailedChangesSource.load($0) }) ?? []
        for change in changes where premiumRejections.contains(where: change.error.hasPrefix) {
            try? await failedChanges.retry(change)
        }
    }
}
