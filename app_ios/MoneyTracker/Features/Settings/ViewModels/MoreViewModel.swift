import Observation

/// The "Lainnya" menu and its logout (APP_FLOWS Flow 12).
@Observable
@MainActor
final class MoreViewModel {
    var showLogoutConfirm = false
    private(set) var pendingChanges = 0

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var version: String { container.config.appVersion }

    /// Counts what logging out would lose: unsent outbox entries and refused changes.
    func askLogout() async {
        let outbox = (try? await container.database.outboxCount()) ?? 0
        pendingChanges = outbox + container.syncStatus.failedChanges.count
        showLogoutConfirm = true
    }

    func logout() async {
        GoogleSignInCoordinator(clientID: container.config.googleClientID).signOut()
        await container.session.logout()
    }
}
