import SwiftUI

struct SetupWizardView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: SetupWizardViewModel
    @State private var showAccountForm = false

    init(container: AppContainer) {
        _model = State(initialValue: SetupWizardViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(
                    value: Double(model.step + 1), total: Double(SetupWizardViewModel.stepCount)
                )
                .padding(.horizontal)
                Group {
                    switch model.step {
                    case 0: cashStep
                    case 1: accountsStep
                    default: categoriesStep
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                if let message = model.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red).padding(.horizontal)
                }
                HStack {
                    if model.step > 0 {
                        Button("Kembali", action: model.back).disabled(model.busy)
                    }
                    Spacer()
                    Text("\(model.step + 1)/\(SetupWizardViewModel.stepCount)")
                        .font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button(model.isLastStep ? "Selesai" : "Lanjut") { Task { await model.next() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.busy)
                }
                .padding()
            }
            .navigationTitle("Atur awal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lewati semua") { Task { await model.skipAll() } }.disabled(model.busy)
                }
            }
            .sheet(isPresented: $showAccountForm) {
                NavigationStack {
                    AccountFormView(container: container, accountId: nil)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Batal") { showAccountForm = false }
                            }
                        }
                }
            }
        }
    }

    private var cashStep: some View {
        Form {
            Section {
                Text("Berapa uang tunai yang kamu pegang sekarang?").font(.title3.bold())
                Text("Ini mengisi saldo awal akun Cash. Kosongkan bila belum mau mengisi.")
                    .foregroundStyle(.secondary)
            }
            Section { MoneyField(title: "Saldo saat ini", text: $model.cashText) }
        }
    }

    private var accountsStep: some View {
        let accounts = container.lookups.accounts.values
            .filter { $0.archivedAt == nil }.sorted { $0.sortOrder < $1.sortOrder }
        return Form {
            Section {
                Text("Tambahkan rekening & e-wallet").font(.title3.bold())
                Text("Masukkan saldo tiap akun saat ini. Kamu bisa menambah lagi nanti.")
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(accounts) { account in
                    HStack(spacing: 12) {
                        ProviderLogoView(providerKey: account.providerKey)
                        Text(account.name)
                    }
                }
                Button("Tambah akun", systemImage: "plus") { showAccountForm = true }
            }
        }
    }

    private var categoriesStep: some View {
        let categories = container.lookups.categories.values.filter { $0.deletedAt == nil }
        return Form {
            Section {
                Text("Sembunyikan kategori yang tidak relevan").font(.title3.bold())
                Text(
                    "Kategori tersembunyi tidak muncul di form transaksi. Bisa diubah lagi di Lainnya → Kategori."
                )
                .foregroundStyle(.secondary)
            }
            ForEach(["expense", "income"], id: \.self) { type in
                Section(type == "expense" ? "Pengeluaran" : "Pemasukan") {
                    ForEach(
                        categories.filter { $0.type == type }.sorted { $0.sortOrder < $1.sortOrder }
                    ) {
                        category in
                        Toggle(
                            isOn: Binding(
                                get: { !category.isHidden },
                                set: { visible in
                                    Task { await model.setHidden(category, hidden: !visible) }
                                })
                        ) {
                            Label {
                                Text(category.name)
                            } icon: {
                                Image(systemName: CategoryIcons.symbol(category.icon))
                                    .foregroundStyle(CategoryIcons.color(category.color))
                            }
                        }
                    }
                }
            }
        }
    }
}
