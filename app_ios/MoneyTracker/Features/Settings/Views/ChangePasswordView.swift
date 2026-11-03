import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ChangePasswordViewModel

    init(container: AppContainer) {
        _model = State(initialValue: ChangePasswordViewModel(container: container))
    }

    var body: some View {
        Form {
            Section {
                PasswordField(title: "Password saat ini", text: $model.current)
                if let error = model.currentError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
                PasswordField(title: "Password baru", text: $model.new, contentType: .newPassword)
                if let error = model.newError { Text(error).font(.footnote).foregroundStyle(.red) }
            } footer: {
                Text("Perangkat lain akan diminta masuk lagi.")
            }
            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Ubah password")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { await model.save() } }.disabled(model.busy)
            }
        }
        .alert("Password diubah.", isPresented: .constant(model.done)) {
            Button("OK") { dismiss() }
        }
    }
}
