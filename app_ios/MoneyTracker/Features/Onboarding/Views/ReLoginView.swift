import SwiftUI

/// Login over a session that ended (`needs_login`). The app stays usable underneath; data and
/// outbox are kept (SYNC_PROTOCOL §11).
struct ReLoginView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var path: [AuthFlowView.Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            LoginView(
                container: container, onForgotPassword: { path.append(.forgotPassword) },
                onRegister: nil
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
            }
            .navigationDestination(for: AuthFlowView.Route.self) { route in
                switch route {
                case .forgotPassword:
                    ForgotPasswordView(
                        container: container, onSent: { path.append(.resetPassword(email: $0)) })
                case .resetPassword(let email):
                    ResetPasswordView(container: container, email: email, onDone: { path = [] })
                case .login, .register:
                    EmptyView()
                }
            }
        }
    }
}
