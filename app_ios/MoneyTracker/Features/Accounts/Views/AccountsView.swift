import SwiftUI

/// Accounts tab (APP_FLOWS Flow 5). Real balances and the reconciliation arrive in Fase 2.
struct AccountsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: AccountsViewModel

    init(container: AppContainer) {
        _model = State(initialValue: AccountsViewModel(container: container))
    }

    var body: some View {
        List {
            if model.loaded && model.items.isEmpty {
                EmptyStateView(
                    title: "Belum ada akun",
                    message: "Tambahkan rekening, e-wallet, atau dompet tunai.",
                    systemImage: "creditcard", actionTitle: "Tambah akun"
                ) { container.router.accountsPath.append(AppRoute.accountForm(id: nil)) }
                .listRowBackground(Color.clear)
            } else if !model.items.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total saldo tercatat").font(.subheadline).foregroundStyle(.secondary)
                        AmountText(
                            amount: model.expectedTotal, hidden: container.preferences.hideAmounts
                        )
                        .font(.title.bold())
                    }
                }
                ForEach(AccountTypeLabels.values, id: \.self) { type in
                    let rows = model.active.filter { $0.account.type == type }
                    if !rows.isEmpty { section(AccountTypeLabels.label(type), rows) }
                }
                if !model.archived.isEmpty {
                    section(String(localized: "Diarsipkan"), model.archived)
                }
            }
        }
        .navigationTitle("Akun")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Tambah akun", systemImage: "plus") {
                    container.router.accountsPath.append(AppRoute.accountForm(id: nil))
                }
            }
        }
        .refreshable { await container.scheduler.syncNow() }
        .task { await model.start() }
    }

    private func section(_ title: String, _ rows: [AccountWithBalance]) -> some View {
        Section(title) {
            ForEach(rows) { item in
                NavigationLink(value: AppRoute.accountDetail(id: item.account.id)) {
                    AccountTile(item: item)
                }
            }
        }
    }
}
