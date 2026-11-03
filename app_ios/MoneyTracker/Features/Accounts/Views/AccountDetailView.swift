import SwiftUI

struct AccountDetailView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: AccountDetailViewModel
    @State private var confirmDelete = false
    @State private var archiveChoice = false

    init(container: AppContainer, accountId: String) {
        _model = State(
            initialValue: AccountDetailViewModel(container: container, accountId: accountId))
    }

    var body: some View {
        Group {
            if let account = model.account {
                content(account)
            } else if model.loaded {
                EmptyStateView(
                    title: "Belum ada data", message: "", systemImage: "questionmark.circle")
            } else {
                ProgressView()
            }
        }
        .navigationTitle(model.account?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { menu }
        .task { await model.start() }
        .alert("Hapus akun ini permanen?", isPresented: $confirmDelete) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                Task { if await model.delete() { dismiss() } }
            }
        }
        .alert(
            "Saldo masih tersisa", isPresented: $archiveChoice
        ) {
            Button("Transfer sisa saldo") {
                container.router.openTransactionForm(
                    type: "transfer", fromAccountId: model.accountId, amount: model.expectedBalance)
            }
            Button("Arsipkan saja") { Task { await model.archive() } }
            Button("Batal", role: .cancel) {}
        } message: {
            Text(
                "Saldo akun ini \(MoneyFormatter.rupiah(model.expectedBalance, hidden: container.preferences.hideAmounts)). Transfer sisa saldo ke akun lain sebelum diarsipkan?"
            )
        }
        .alert(
            "Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ToolbarContentBuilder
    private var menu: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if let account = model.account {
                Menu {
                    Button("Ubah", systemImage: "pencil") {
                        container.router.push(.accountForm(id: account.id))
                    }
                    if account.archivedAt == nil {
                        Button("Arsipkan", systemImage: "archivebox") {
                            if model.expectedBalance != 0 {
                                archiveChoice = true
                            } else {
                                Task { await model.archive() }
                            }
                        }
                    } else {
                        Button("Aktifkan lagi", systemImage: "arrow.uturn.backward") {
                            Task { await model.unarchive() }
                        }
                    }
                    Button("Hapus", systemImage: "trash", role: .destructive) {
                        confirmDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func content(_ account: AccountRecord) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    ProviderLogoView(providerKey: account.providerKey, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saldo menurut catatan").font(.subheadline).foregroundStyle(.secondary)
                        AmountText(
                            amount: model.expectedBalance, hidden: container.preferences.hideAmounts
                        )
                        .font(.title2.bold())
                    }
                }
                if account.archivedAt != nil {
                    Label(
                        "Akun ini diarsipkan: tidak muncul di form transaksi baru.",
                        systemImage: "archivebox"
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Transaksi akun") {
                if model.recent.isEmpty {
                    Text("Belum ada transaksi di akun ini.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.recent) { row in
                        Button {
                            container.router.openTransaction(id: row.id)
                        } label: {
                            TransactionRow(transaction: row, viewpointAccountId: account.id)
                        }
                        .buttonStyle(.plain)
                    }
                    Button("Lihat semua") {
                        container.router.showTransactions(
                            filter: TransactionFilter(accountId: account.id))
                    }
                }
            }
            Section("Riwayat saldo") {
                if model.snapshots.isEmpty {
                    Text("Belum ada riwayat saldo.").foregroundStyle(.secondary)
                } else {
                    ForEach(model.snapshots) { snapshot in
                        HStack {
                            Text(snapshot.snapshotDate.shortText)
                            Spacer()
                            AmountText(
                                amount: snapshot.amount, hidden: container.preferences.hideAmounts)
                        }
                    }
                }
            }
        }
    }
}
