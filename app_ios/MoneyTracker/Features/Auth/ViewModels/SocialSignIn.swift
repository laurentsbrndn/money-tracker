import AuthenticationServices

/// Apple and Google login on top of `AuthSubmission`, shared by the login and register screens.
@MainActor
struct SocialSignIn {
    let container: AppContainer
    let submission: AuthSubmission

    private var repository: AuthRepository { AuthRepository(client: container.api.client) }

    func google() async {
        await submission.run { discard in
            let coordinator = GoogleSignInCoordinator(clientID: container.config.googleClientID)
            guard let credential = try await coordinator.signIn() else { return }
            let response = try await repository.loginWithGoogle(credential)
            try await container.session.establish(response, discardLocalData: discard)
        }
    }

    func apple(_ result: Result<ASAuthorization, any Error>, nonce: String) async {
        switch result {
        case .failure(let error):
            if !AppleSignInCoordinator.isCancellation(error) {
                submission.errorMessage = String(localized: "Gagal masuk dengan Apple. Coba lagi.")
            }
        case .success(let authorization):
            guard
                let credential = AppleSignInCoordinator.credential(
                    from: authorization, nonce: nonce)
            else {
                submission.errorMessage = String(localized: "Gagal masuk dengan Apple. Coba lagi.")
                return
            }
            await submission.run { discard in
                let response = try await repository.loginWithApple(credential)
                try await container.session.establish(response, discardLocalData: discard)
            }
        }
    }
}
