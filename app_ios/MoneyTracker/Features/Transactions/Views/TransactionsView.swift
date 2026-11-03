import SwiftUI

/// Transactions tab: history grouped by day with search, filter, delete + undo, duplicate.
struct TransactionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: TransactionsViewModel
    @State private var showFilter = false

    init(container: AppContainer) {
        _model = State(initialValue: TransactionsViewModel(container: container))
    }

    var body: some View {
        List {
            if model.loaded && model.rows.isEmpty {
                if model.filter.isEmpty {
                    EmptyStateView(
                        title: "Belum ada transaksi",
                        message: "Transaksi yang kamu catat muncul di sini.",
                        systemImage: "list.bullet"
                    )
                    .listRowBackground(Color.clear)
                } else {
                    EmptyStateView(
                        title: "Tidak ada hasil", message: "Coba ubah atau hapus filter pencarian.",
                        systemImage: "magnifyingglass", actionTitle: "Hapus filter"
                    ) { model.clearFilters() }
                    .listRowBackground(Color.clear)
                }
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.transactions) { row in
                        Button {
                            container.router.openTransaction(id: row.id)
                        } label: {
                            TransactionRow(transaction: row)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button("Hapus", role: .destructive) { Task { await model.delete(row) } }
                        }
                        .contextMenu {
                            if row.type != "adjustment" {
                                Button("Duplikat", systemImage: "plus.square.on.square") {
                                    Task { await model.duplicate(row) }
                                }
                            }
                        }
                        .onAppear {
                            if row.id == model.rows.last?.id { model.loadMore() }
                        }
                    }
                } header: {
                    HStack {
                        Text(group.date.longText)
                        Spacer()
                        AmountText(
                            amount: group.net, hidden: container.preferences.hideAmounts)
                    }
                    .textCase(nil)
                }
            }
        }
        .navigationTitle("Transaksi")
        .searchable(text: $model.searchText, prompt: "Cari catatan atau sumber")
        .onChange(of: model.searchText) { model.searchChanged() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showFilter = true
                } label: {
                    Label(
                        "Filter",
                        systemImage: model.filter.activeCount > 0
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .refreshable { await container.scheduler.syncNow() }
        .overlay(alignment: .bottomTrailing) { AddTransactionButton() }
        .task(id: model.observationKey) { await model.observe() }
        .onAppear(perform: takePendingFilter)
        .onChange(of: container.router.pendingTransactionFilter) { takePendingFilter() }
        .sheet(isPresented: $showFilter) {
            TransactionFilterSheet(container: container, initial: model.filter) { model.apply($0) }
        }
        .safeAreaInset(edge: .bottom) {
            if model.undoable != nil {
                UndoBanner(message: "Transaksi dihapus") { Task { await model.undoDelete() } }
            }
        }
        .animation(.default, value: model.undoable == nil)
        .alert("Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(model.notice ?? "", isPresented: .constant(model.notice != nil)) {
            Button("OK") { model.notice = nil }
        }
    }

    private func takePendingFilter() {
        if let pending = container.router.pendingTransactionFilter {
            container.router.pendingTransactionFilter = nil
            model.apply(pending)
        }
    }
}
