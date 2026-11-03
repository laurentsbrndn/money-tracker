import SwiftUI

struct SyncSettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: SyncSettingsViewModel
    @State private var selected: FailedChange?
    @State private var confirmDiscard: FailedChange?

    init(container: AppContainer) {
        _model = State(initialValue: SyncSettingsViewModel(container: container))
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Terakhir sinkron") {
                    Text(model.lastSyncAt.map(Self.format) ?? String(localized: "Belum pernah"))
                }
                LabeledContent("Menunggu dikirim") {
                    Text("\(model.pendingCount)").monospacedDigit()
                }
                Button {
                    Task { await model.syncNow() }
                } label: {
                    HStack {
                        Label("Sync sekarang", systemImage: "arrow.triangle.2.circlepath")
                        if model.syncing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(model.syncing)
            }
            Section("Perlu perhatian") {
                if model.failed.isEmpty {
                    Text("Semua perubahan sudah diterima server.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.failed) { change in
                        Button {
                            selected = change
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(
                                        Self.title(
                                            change, hidden: container.preferences.hideAmounts)
                                    ).foregroundStyle(.primary)
                                    Text(SyncSettingsViewModel.reason(change.error))
                                        .font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Sinkronisasi")
        .confirmationDialog(
            "Server menolak perubahan ini. Perbaiki lalu kirim ulang, atau buang perubahan dan ambil versi dari server.",
            isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }),
            titleVisibility: .visible, presenting: selected
        ) { change in
            if model.canFix(change) { Button("Perbaiki") { model.fix(change) } }
            Button("Kirim ulang") { Task { await model.retry(change) } }
            Button("Buang perubahan", role: .destructive) { confirmDiscard = change }
        }
        .alert(
            "Buang perubahan ini dan ambil versi dari server?",
            isPresented: Binding(
                get: { confirmDiscard != nil }, set: { if !$0 { confirmDiscard = nil } })
        ) {
            Button("Batal", role: .cancel) {}
            Button("Buang perubahan", role: .destructive) {
                if let change = confirmDiscard { Task { await model.discard(change) } }
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

    private static func title(_ change: FailedChange, hidden: Bool) -> String {
        [
            SyncSettingsViewModel.entityLabel(change.entity),
            change.title.isEmpty ? nil : change.title,
            change.amount.map { MoneyFormatter.rupiah($0, hidden: hidden) },
            change.isDelete ? String(localized: "(dihapus)") : nil,
        ].compactMap { $0 }.joined(separator: " · ")
    }

    private static func format(_ date: Date) -> String {
        date.formatted(
            .dateTime.day().month(.abbreviated).year().hour().minute().locale(
                Locale(identifier: "id_ID")))
    }
}
