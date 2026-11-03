import Observation

@Observable
@MainActor
final class VerifyEmailViewModel {
    var code = ""
    private(set) var codeError: String?
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var verified = false

    private let container: AppContainer
    private let repository: AuthRepository

    init(container: AppContainer) {
        self.container = container
        repository = AuthRepository(client: container.api.client)
    }

    var email: String { container.session.user?.email ?? "" }

    func verify() async {
        codeError = AuthValidators.code(code)
        guard codeError == nil else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            let user = try await repository.verifyEmail(
                code: code.trimmingCharacters(in: .whitespaces))
            container.session.updateUser(user)
            verified = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func resend() async {
        notice = nil
        errorMessage = nil
        do {
            try await repository.resendEmailVerification()
            notice = String(localized: "Kode baru dikirim.")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
