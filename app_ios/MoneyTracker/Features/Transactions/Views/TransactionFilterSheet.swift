import SwiftUI

/// Filter by type, account, category, allocation, and date range (APP_FLOWS Flow 4).
struct TransactionFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @State private var filter: TransactionFilter
    let onApply: (TransactionFilter) -> Void

    init(
        container: AppContainer, initial: TransactionFilter,
        onApply: @escaping (TransactionFilter) -> Void
    ) {
        _filter = State(initialValue: initial)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Tipe", selection: $filter.type) {
                    Text("Semua").tag(String?.none)
                    Text("Expense").tag(String?.some("expense"))
                    Text("Income").tag(String?.some("income"))
                    Text("Transfer").tag(String?.some("transfer"))
                    Text("Penyesuaian").tag(String?.some("adjustment"))
                }
                Picker("Akun", selection: $filter.accountId) {
                    Text("Semua").tag(String?.none)
                    ForEach(accounts) { Text($0.name).tag(String?.some($0.id)) }
                }
                Picker("Kategori", selection: $filter.categoryId) {
                    Text("Semua").tag(String?.none)
                    ForEach(categories) { Text($0.name).tag(String?.some($0.id)) }
                }
                Picker("Alokasi", selection: $filter.allocation) {
                    Text("Semua").tag(String?.none)
                    Text("Needs").tag(String?.some("needs"))
                    Text("Wants").tag(String?.some("wants"))
                    Text("Savings").tag(String?.some("savings"))
                }
                Section("Rentang tanggal") {
                    dateRow("Dari", \.from)
                    dateRow("Sampai", \.to)
                }
            }
            .navigationTitle("Filter transaksi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        let query = filter.query
                        filter = TransactionFilter(query: query)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan") {
                        onApply(filter)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var accounts: [AccountRecord] {
        container.lookups.accounts.values.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var categories: [CategoryRecord] {
        container.lookups.categories.values.sorted {
            ($0.type, $0.sortOrder) < ($1.type, $1.sortOrder)
        }
    }

    @ViewBuilder
    private func dateRow(
        _ title: LocalizedStringKey, _ keyPath: WritableKeyPath<TransactionFilter, CivilDate?>
    )
        -> some View
    {
        if let value = filter[keyPath: keyPath] {
            DatePicker(
                title,
                selection: Binding(
                    get: { value.date() },
                    set: { filter[keyPath: keyPath] = CivilDate($0, in: .current) }),
                displayedComponents: .date)
            Button("Semua tanggal", role: .destructive) { filter[keyPath: keyPath] = nil }
        } else {
            Button {
                filter[keyPath: keyPath] = UserClock.today()
            } label: {
                HStack {
                    Text(title).foregroundStyle(.primary)
                    Spacer()
                    Text("Semua tanggal").foregroundStyle(.secondary)
                }
            }
        }
    }
}
