import SwiftUI

/// Lainnya → Keamanan.
struct SecurityView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: SecurityViewModel

    init(container: AppContainer) {
        _model = State(initialValue: SecurityViewModel(container: container))
    }

    private var lock: AppLockController { container.lock }

    var body: some View {
        Form {
            Section {
                Toggle(
                    isOn: Binding(
                        get: { lock.pinSet },
                        set: { on in
                            container.router.push(.securityPin(on ? .set : .remove))
                        })
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kunci aplikasi dengan PIN")
                        Text("PIN 6 digit diminta saat aplikasi dibuka.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if lock.pinSet {
                    Button("Ubah PIN") { container.router.push(.securityPin(.change)) }
                    if model.biometricAvailable {
                        Toggle(
                            "Buka dengan \(model.biometricName)",
                            isOn: Binding(
                                get: { lock.biometricEnabled },
                                set: { on in Task { await model.setBiometric(on) } }))
                    } else {
                        Text("Perangkat belum punya biometrik yang terdaftar.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker(
                        "Kunci otomatis",
                        selection: Binding(
                            get: { lock.autoLockSeconds }, set: { model.setAutoLock($0) })
                    ) {
                        Text("Segera setelah ke latar belakang").tag(0)
                        Text("Setelah 1 menit").tag(60)
                        Text("Setelah 5 menit").tag(300)
                    }
                }
            } footer: {
                Text("PIN dan biometrik hanya tersimpan di perangkat ini dan tidak disinkronkan.")
            }
            Section {
                Toggle(
                    isOn: Binding(
                        get: { container.preferences.hideAmounts },
                        set: { hide in Task { await model.setHideAmounts(hide) } })
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sembunyikan nominal")
                        Text("Nominal tampil sebagai Rp •••••. Berlaku di semua perangkatmu.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .disabled(container.preferences.settings == nil)
            }
        }
        .navigationTitle("Keamanan")
        .alert(
            "Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
