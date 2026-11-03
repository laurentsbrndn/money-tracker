import SwiftUI

/// Everything before a session exists: onboarding, then login, register, and password reset.
struct AuthFlowView: View {
    @Environment(AppContainer.self) private var container
    @State private var path: [Route] = []

    enum Route: Hashable {
        case login
        case register
        case forgotPassword
        case resetPassword(email: String)
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingView(onStart: { path = [.register] }, onLogin: { path = [.login] })
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .login:
                        LoginView(
                            container: container,
                            onForgotPassword: { path.append(.forgotPassword) },
                            onRegister: { path = [.register] })
                    case .register:
                        RegisterView(container: container, onLogin: { path = [.login] })
                    case .forgotPassword:
                        ForgotPasswordView(
                            container: container, onSent: { path.append(.resetPassword(email: $0)) }
                        )
                    case .resetPassword(let email):
                        ResetPasswordView(
                            container: container, email: email, onDone: { path = [.login] })
                    }
                }
        }
    }
}
