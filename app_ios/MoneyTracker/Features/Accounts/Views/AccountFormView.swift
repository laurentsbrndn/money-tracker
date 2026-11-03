import SwiftUI

struct AccountFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: AccountFormViewModel

    init(container: AppContainer, accountId: String?) {
        _model = State(
            initialValue: AccountFormViewModel(container: container, accountId: accountId))
    }

    var body: some View {
        Form {
            Section {
                Picker("Tipe akun", selection: $model.type) {
                    ForEach(AccountTypeLabels.values, id: \.self) { type in
                        Text(AccountTypeLabels.label(type)).tag(type)
                    }
                }
                if model.type != "cash" {
                    ProviderPicker(selection: $model.providerKey)
                }
                TextField("Nama akun", text: $model.name)
                MoneyField(
                    title: model.isEditing ? "Saldo awal" : "Saldo saat ini",
                    text: $model.balanceText, allowNegative: true)
                DatePicker(
                    "Tanggal saldo awal",
                    selection: Binding(
                        get: { model.openingDate.date() },
                        set: { model.openingDate = CivilDate($0, in: .current) }),
                    displayedComponents: .date)
                Toggle("Hitung di total", isOn: $model.includeInTotal)
            } footer: {
                Text(
                    "Saldo ini menjadi saldo awal akun; transaksi sebelum tanggal ini tidak bisa dicatat."
                )
            }
            if let message = model.errorMessage {
                Section { Text(message).foregroundStyle(.red) }
            }
        }
        .navigationTitle(model.isEditing ? "Ubah akun" : "Tambah akun")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Simpan") { Task { await model.save() } }.disabled(model.busy)
            }
        }
        .task { await model.load() }
        .onChange(of: model.saved) { _, saved in if saved { dismiss() } }
    }
}

/// The logo grid of the account form.
private struct ProviderPicker: View {
    @Binding var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logo").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
                ForEach(ProviderLogos.all) { provider in
                    VStack(spacing: 4) {
                        ProviderLogoView(providerKey: provider.key, size: 40)
                            .padding(3)
                            .overlay(
                                Circle().stroke(
                                    selection == provider.key ? AppColors.seed : .clear,
                                    lineWidth: 2))
                        Text(provider.name).font(.caption2).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selection = selection == provider.key ? nil : provider.key }
                }
            }
        }
    }
}
