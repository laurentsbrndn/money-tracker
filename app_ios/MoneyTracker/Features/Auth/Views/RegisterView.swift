import SwiftUI

struct RegisterView: View {
    @State private var model: RegisterViewModel
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    let onLogin: () -> Void

    init(container: AppContainer, onLogin: @escaping () -> Void) {
        _model = State(initialValue: RegisterViewModel(container: container))
        self.onLogin = onLogin
    }

    var body: some View {
        AuthScaffold(
            title: "Buat akun",
            subtitle: Text("Gratis. Datamu tersimpan di perangkat dan tersinkron ke server.")
        ) {
            SocialSignInButtons(social: model.social, disabled: model.submission.busy)

            AuthField(error: model.nameError) {
                TextField("Nama", text: $model.name)
                    .textContentType(.name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .email }
            }
            AuthField(error: model.emailError) {
                TextField("Email", text: $model.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            AuthField(error: model.passwordError) {
                PasswordField(title: "Password", text: $model.password, contentType: .newPassword)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await model.register() } }
            }
            if let message = model.submission.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await model.register() }
            } label: {
                if model.submission.busy { ProgressView().tint(.white) } else { Text("Daftar") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.submission.busy)

            Button("Sudah punya akun? Masuk", action: onLogin)
                .disabled(model.submission.busy)
                .frame(maxWidth: .infinity)
        }
        .userMismatchAlert(model.submission)
    }
}
