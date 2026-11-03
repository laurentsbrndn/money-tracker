import SwiftUI

struct ForgotPasswordView: View {
    @State private var model: ForgotPasswordViewModel
    let onSent: (String) -> Void

    init(container: AppContainer, onSent: @escaping (String) -> Void) {
        _model = State(initialValue: ForgotPasswordViewModel(container: container))
        self.onSent = onSent
    }

    var body: some View {
        AuthScaffold(
            title: "Lupa password",
            subtitle: Text(
                "Masukkan email akunmu. Kami kirim kode 6 digit untuk membuat password baru.")
        ) {
            AuthField(error: model.emailError) {
                TextField("Email", text: $model.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit { Task { await model.send() } }
            }
            if let message = model.errorMessage {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await model.send() }
            } label: {
                if model.busy { ProgressView().tint(.white) } else { Text("Kirim kode") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.busy)
        }
        .onChange(of: model.sentTo) { _, address in
            guard let address else { return }
            model.didNavigate()
            onSent(address)
        }
    }
}
