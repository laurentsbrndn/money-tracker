import SwiftUI

struct DeleteAccountView: View {
    @State private var model: DeleteAccountViewModel

    init(container: AppContainer) {
        _model = State(initialValue: DeleteAccountViewModel(container: container))
    }

    var body: some View {
        Form {
            Section {
                Text(
                    "Akun dan seluruh datamu akan dihapus dan tidak bisa dikembalikan. Penghapusan permanen dilakukan setelah 30 hari."
                )
                Text(
                    "Jika kamu berlangganan Premium, batalkan langganan di pengaturan App Store. Menghapus akun tidak menghentikan tagihan."
                )
                .foregroundStyle(.secondary)
            }
            Section {
                if model.needsPassword {
                    PasswordField(
                        title: "Masukkan password untuk konfirmasi", text: $model.confirmation)
                } else {
                    TextField("Ketik HAPUS untuk konfirmasi", text: $model.confirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            Section {
                Button("Hapus akun saya", role: .destructive) { Task { await model.delete() } }
                    .disabled(model.busy || model.confirmation.isEmpty)
            }
            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Hapus akun")
    }
}
