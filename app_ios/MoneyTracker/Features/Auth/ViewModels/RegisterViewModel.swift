import Observation

@Observable
@MainActor
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    private(set) var nameError: String?
    private(set) var emailError: String?
    private(set) var passwordError: String?

    let submission = AuthSubmission()
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var social: SocialSignIn { SocialSignIn(container: container, submission: submission) }

    func register() async {
        nameError = AuthValidators.required(name)
        emailError = AuthValidators.email(email)
        passwordError = AuthValidators.password(password)
        guard nameError == nil, emailError == nil, passwordError == nil else { return }
        let name = String(name.trimmingCharacters(in: .whitespaces).prefix(100))
        let email = email.trimmingCharacters(in: .whitespaces)
        let password = password
        let repository = AuthRepository(client: container.api.client)
        await submission.run { [container] discard in
            let response = try await repository.register(
                name: name, email: email, password: password)
            try await container.session.establish(response, discardLocalData: discard)
        }
    }
}
