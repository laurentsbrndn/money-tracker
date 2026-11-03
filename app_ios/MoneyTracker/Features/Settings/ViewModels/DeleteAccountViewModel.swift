import Observation

@Observable
@MainActor
final class DeleteAccountViewModel {
    var confirmation = ""
    private(set) var busy = false
    var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    /// Users with a password confirm with it; social-only users type `HAPUS`.
    var needsPassword: Bool { container.session.user?.hasPassword ?? false }

    func delete() async {
        if !needsPassword && confirmation != "HAPUS" {
            errorMessage = String(localized: "Ketik HAPUS dengan huruf besar.")
            return
        }
        guard !confirmation.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            try await container.settings.deleteAccount(confirmation: confirmation)
            GoogleSignInCoordinator(clientID: container.config.googleClientID).signOut()
            await container.session.clearLocalSession()
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
