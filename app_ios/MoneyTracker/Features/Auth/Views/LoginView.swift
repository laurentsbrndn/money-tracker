import SwiftUI

struct LoginView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: LoginViewModel
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    let onForgotPassword: () -> Void
    let onRegister: (() -> Void)?

    init(container: AppContainer, onForgotPassword: @escaping () -> Void, onRegister: (() -> Void)?)
    {
        _model = State(initialValue: LoginViewModel(container: container))
        self.onForgotPassword = onForgotPassword
        self.onRegister = onRegister
    }

    var body: some View {
        AuthScaffold(
            title: "Masuk", subtitle: Text("Masuk untuk melanjutkan mencatat keuanganmu.")
        ) {
            if container.session.status == .needsLogin {
                Label(
                    "Sesimu berakhir. Masuk lagi untuk melanjutkan sinkronisasi; data di perangkat ini tetap aman.",
                    systemImage: "lock"
                )
                .font(.subheadline)
                .padding(12)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }
            SocialSignInButtons(social: model.social, disabled: model.submission.busy)

            AuthField(error: model.emailError) {
                TextField("Email", text: $model.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            AuthField(error: model.passwordError) {
                PasswordField(title: "Password", text: $model.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.login() } }
            }
            if let message = model.submission.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await model.login() }
            } label: {
                if model.submission.busy { ProgressView().tint(.white) } else { Text("Masuk") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.submission.busy)

            Button("Lupa password?", action: onForgotPassword)
                .disabled(model.submission.busy)
                .frame(maxWidth: .infinity)
            if let onRegister {
                Button("Belum punya akun? Daftar", action: onRegister)
                    .disabled(model.submission.busy)
                    .frame(maxWidth: .infinity)
            }
        }
        .userMismatchAlert(model.submission)
    }
}
