import SwiftUI

/// Lainnya → Preferensi.
struct PreferencesView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: PreferencesViewModel

    init(container: AppContainer) {
        _model = State(initialValue: PreferencesViewModel(container: container))
    }

    var body: some View {
        Form {
            if let settings = container.preferences.settings {
                Section {
                    NavigationLink {
                        TimezonePickerView(selected: settings.timezone) { identifier in
                            Task { await model.setTimezone(identifier) }
                        }
                    } label: {
                        LabeledContent("Timezone") {
                            Text(settings.timezone).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text(
                        "Menentukan \"hari ini\" dan batas bulan. Transaksi yang sudah ada tidak berubah."
                    )
                }
                Section {
                    Picker("Hari pertama minggu", selection: weekStart(settings)) {
                        Text("Senin").tag(1)
                        Text("Minggu").tag(7)
                    }
                    Picker("Tema", selection: theme(settings)) {
                        Text("Ikuti sistem").tag("system")
                        Text("Terang").tag("light")
                        Text("Gelap").tag("dark")
                    }
                }
            } else {
                Text("Pengaturan belum tersedia. Tunggu sinkronisasi selesai.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Preferensi")
        .alert(
            "Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func weekStart(_ settings: UserSettingsRecord) -> Binding<Int> {
        Binding(
            get: { settings.weekStart },
            set: { value in Task { await model.setWeekStart(value) } })
    }

    private func theme(_ settings: UserSettingsRecord) -> Binding<String> {
        Binding(
            get: { settings.theme },
            set: { value in Task { await model.setTheme(value) } })
    }
}
