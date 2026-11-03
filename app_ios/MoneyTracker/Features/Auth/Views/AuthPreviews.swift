#if DEBUG
    import SwiftUI

    #Preview("Login") {
        PreviewHost(variant: .empty, signedOut: true) { container in
            NavigationStack {
                LoginView(container: container, onForgotPassword: {}, onRegister: {})
            }
        }
    }

    #Preview("Login — sesi berakhir") {
        PreviewHost(variant: .needsLogin) { container in
            NavigationStack {
                LoginView(container: container, onForgotPassword: {}, onRegister: nil)
            }
        }
    }

    #Preview("Login — mode gelap") {
        PreviewHost(variant: .dark, signedOut: true) { container in
            NavigationStack {
                LoginView(container: container, onForgotPassword: {}, onRegister: {})
            }
        }
    }

    #Preview("Daftar") {
        PreviewHost(variant: .empty, signedOut: true) { container in
            NavigationStack { RegisterView(container: container, onLogin: {}) }
        }
    }

    #Preview("Daftar — mode gelap") {
        PreviewHost(variant: .dark, signedOut: true) { container in
            NavigationStack { RegisterView(container: container, onLogin: {}) }
        }
    }

    #Preview("Lupa kata sandi") {
        PreviewHost(variant: .empty, signedOut: true) { container in
            NavigationStack { ForgotPasswordView(container: container, onSent: { _ in }) }
        }
    }

    #Preview("Atur ulang kata sandi") {
        PreviewHost(variant: .empty, signedOut: true) { container in
            NavigationStack {
                ResetPasswordView(container: container, email: "brandon@example.com", onDone: {})
            }
        }
    }

    #Preview("Verifikasi email") {
        PreviewHost(variant: .populated) { container in
            VerifyEmailView(container: container)
        }
    }
#endif
