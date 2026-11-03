import SwiftUI

struct ProfileView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: ProfileViewModel

    init(container: AppContainer) {
        _model = State(initialValue: ProfileViewModel(container: container))
    }

    var body: some View {
        Form {
            Section {
                TextField("Nama", text: $model.name)
                LabeledContent(
                    "Email", value: model.user?.email ?? String(localized: "Tidak ada email"))
                if model.user?.email != nil {
                    LabeledContent("Status email") {
                        if model.user?.emailVerified == true {
                            Label("Terverifikasi", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button("Belum terverifikasi") {
                                container.router.showVerifyEmail = true
                            }
                        }
                    }
                }
            }
            Section("Metode masuk") {
                if model.user?.hasPassword == true {
                    Label("Email & password", systemImage: "envelope")
                }
                ForEach(model.user?.providers ?? [], id: \.self) { provider in
                    Label(
                        provider == "apple" ? "Apple" : "Google",
                        systemImage: provider == "apple" ? "apple.logo" : "globe")
                }
                if model.user?.hasPassword == true {
                    NavigationLink("Ubah password", value: AppRoute.changePassword)
                }
            }
        }
        .navigationTitle("Profil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { await model.save() } }.disabled(model.busy)
            }
        }
        .alert(model.notice ?? "", isPresented: .constant(model.notice != nil)) {
            Button("OK") { model.notice = nil }
        }
        .alert("Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
