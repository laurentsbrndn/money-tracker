import Observation

@Observable
@MainActor
final class ForgotPasswordViewModel {
    var email = ""
    private(set) var emailError: String?
    private(set) var busy = false
    private(set) var errorMessage: String?
    /// The email the code was sent to; the reset screen opens with it.
    private(set) var sentTo: String?

    private let repository: AuthRepository

    init(container: AppContainer) {
        repository = AuthRepository(client: container.api.client)
    }

    func send() async {
        emailError = AuthValidators.email(email)
        guard emailError == nil else { return }
        let address = email.trimmingCharacters(in: .whitespaces)
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try await repository.forgotPassword(email: address)
            sentTo = address
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func didNavigate() {
        sentTo = nil
    }
}
