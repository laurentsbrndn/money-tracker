import SwiftUI

struct ResetPasswordView: View {
    @State private var model: ResetPasswordViewModel
    let onDone: () -> Void

    init(container: AppContainer, email: String, onDone: @escaping () -> Void) {
        _model = State(initialValue: ResetPasswordViewModel(container: container, email: email))
        self.onDone = onDone
    }

    var body: some View {
        AuthScaffold(
            title: "Password baru",
            subtitle: Text("Masukkan kode yang dikirim ke emailmu dan password baru.")
        ) {
            AuthField(error: model.codeError) {
                TextField("Kode 6 digit", text: $model.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.title2.monospacedDigit())
                    .onChange(of: model.code) { _, value in
                        let digits = String(value.filter(\.isNumber).prefix(6))
                        if digits != value { model.code = digits }
                    }
            }
            AuthField(error: model.passwordError) {
                PasswordField(
                    title: "Password baru", text: $model.newPassword, contentType: .newPassword
                )
                .submitLabel(.go)
                .onSubmit { Task { await model.reset() } }
            }
            if let message = model.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await model.reset() }
            } label: {
                if model.busy { ProgressView().tint(.white) } else { Text("Ubah password") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.busy)
        }
        .alert(
            "Password diubah. Silakan masuk dengan password baru.",
            isPresented: .constant(model.done)
        ) {
            Button("OK", action: onDone)
        }
    }
}
