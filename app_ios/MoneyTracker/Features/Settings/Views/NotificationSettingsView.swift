import SwiftUI

/// Lainnya → Notifikasi.
struct NotificationSettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: NotificationSettingsViewModel

    init(container: AppContainer) {
        _model = State(initialValue: NotificationSettingsViewModel(container: container))
    }

    var body: some View {
        Form {
            if let settings = container.preferences.settings {
                if !model.permissionGranted { permissionCard }
                Section {
                    Toggle(isOn: dailyBinding(settings)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pengingat harian")
                            Text(dailySubtitle(settings))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let time = settings.dailyReminderTime {
                        DatePicker(
                            "Jam pengingat",
                            selection: Binding(
                                get: { NotificationSettingsViewModel.date(from: time) },
                                set: { date in
                                    Task {
                                        await model.setDailyTime(
                                            NotificationSettingsViewModel.time(from: date))
                                    }
                                }),
                            displayedComponents: .hourAndMinute
                        )
                        .environment(\.timeZone, .gmt)
                    }
                    Toggle(
                        isOn: Binding(
                            get: { settings.reconcileReminderEnabled },
                            set: { on in Task { await model.setReconcile(enabled: on) } })
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pengingat cocokkan saldo")
                            Text(
                                "Akhir bulan pukul 20.00 dan saat ada akun yang saldonya sudah lebih dari 7 hari."
                            )
                            .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(
                        isOn: Binding(
                            get: { settings.budgetAlertEnabled },
                            set: { on in Task { await model.setBudgetAlert(enabled: on) } })
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Peringatan budget")
                            Text(
                                "Saat needs atau wants mencapai 80% dan 100% goal, serta evaluasi tiap tanggal 1."
                            )
                            .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Bila Sembunyikan nominal aktif, notifikasi tidak menampilkan nominal.")
                }
            } else {
                Text("Pengaturan belum tersedia. Tunggu sinkronisasi selesai.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Notifikasi")
        .task { await model.refreshPermission() }
        .onChange(of: scenePhase) { _, phase in
            // Back from the system settings: re-read the permission.
            if phase == .active { Task { await model.refreshPermission() } }
        }
        .alert(
            "Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var permissionCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Izin notifikasi belum aktif", systemImage: "bell.slash.fill")
                    .font(.headline).foregroundStyle(AppColors.warning)
                Text("Tanpa izin, pengingat dan peringatan tidak akan muncul.")
                    .font(.footnote)
                if model.permissionUndetermined {
                    Button("Izinkan") { Task { await model.ensurePermission() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Buka pengaturan") { model.openSystemSettings() }
                        .buttonStyle(.bordered)
                }
            }
        }
    }

    private func dailyBinding(_ settings: UserSettingsRecord) -> Binding<Bool> {
        Binding(
            get: { settings.dailyReminderTime != nil },
            set: { on in Task { await model.setDaily(enabled: on) } })
    }

    private func dailySubtitle(_ settings: UserSettingsRecord) -> String {
        guard let time = settings.dailyReminderTime else { return String(localized: "Mati") }
        return String(
            localized: "Setiap hari pukul \(time); dilewati bila hari itu sudah ada transaksi.")
    }
}
