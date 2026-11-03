import Observation

@Observable
@MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var emailError: String?
    private(set) var passwordError: String?

    let submission = AuthSubmission()
    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var social: SocialSignIn { SocialSignIn(container: container, submission: submission) }

    func login() async {
        emailError = AuthValidators.email(email)
        passwordError = AuthValidators.required(password)
        guard emailError == nil, passwordError == nil else { return }
        let email = email.trimmingCharacters(in: .whitespaces)
        let password = password
        let repository = AuthRepository(client: container.api.client)
        await submission.run { [container] discard in
            let response = try await repository.login(email: email, password: password)
            try await container.session.establish(response, discardLocalData: discard)
        }
    }
}
