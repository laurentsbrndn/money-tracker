import Observation

@Observable
@MainActor
final class ResetPasswordViewModel {
    let email: String
    var code = ""
    var newPassword = ""
    private(set) var codeError: String?
    private(set) var passwordError: String?
    private(set) var busy = false
    private(set) var errorMessage: String?
    private(set) var done = false

    private let repository: AuthRepository

    init(container: AppContainer, email: String) {
        self.email = email
        repository = AuthRepository(client: container.api.client)
    }

    func reset() async {
        codeError = AuthValidators.code(code)
        passwordError = AuthValidators.password(newPassword)
        guard codeError == nil, passwordError == nil else { return }
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try await repository.resetPassword(
                email: email, code: code.trimmingCharacters(in: .whitespaces),
                newPassword: newPassword)
            done = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
