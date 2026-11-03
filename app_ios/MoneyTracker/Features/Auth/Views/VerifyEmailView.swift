import SwiftUI

/// Input of the 6-digit email code. Shown as a sheet from the dashboard banner; the app stays
/// usable without it (APP_FLOWS Flow 1, step 3.2).
struct VerifyEmailView: View {
    @State private var model: VerifyEmailViewModel
    @Environment(\.dismiss) private var dismiss

    init(container: AppContainer) {
        _model = State(initialValue: VerifyEmailViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            AuthScaffold(
                title: "Verifikasi email",
                subtitle: Text(
                    "Kami mengirim kode 6 digit ke \(model.email). Masukkan kode itu di bawah.")
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
                if let message = model.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
                if let notice = model.notice {
                    Text(notice).font(.footnote).foregroundStyle(.secondary)
                }
                Button {
                    Task { await model.verify() }
                } label: {
                    if model.busy { ProgressView().tint(.white) } else { Text("Verifikasi") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(model.busy)

                Button("Kirim ulang kode") { Task { await model.resend() } }
                    .disabled(model.busy)
                    .frame(maxWidth: .infinity)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Nanti saja") { dismiss() }
                }
            }
            .onChange(of: model.verified) { _, verified in
                if verified { dismiss() }
            }
        }
    }
}
