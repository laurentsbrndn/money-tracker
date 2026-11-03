import SwiftUI

/// Dashboard tab (APP_FLOWS Flow 2).
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: DashboardViewModel

    init(container: AppContainer) {
        _model = State(initialValue: DashboardViewModel(container: container))
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    if let user = container.session.user, user.email != nil, !user.emailVerified {
                        VerifyEmailBanner { container.router.showVerifyEmail = true }
                    }
                    MonthSelector(
                        month: model.month, canGoNext: model.canGoNext,
                        isLocked: !model.canView(model.month), onPrevious: model.previousMonth,
                        onNext: model.nextMonth)
                    if model.canView(model.month) {
                        let hidden = container.preferences.hideAmounts
                        SummaryCard(summary: model.summary, hidden: hidden)
                        ActualMoneyCard(
                            overview: model.overview, hidden: hidden,
                            onTap: { container.router.selectedTab = .accounts })
                        DifferenceCard(
                            overview: model.overview, hidden: hidden,
                            onReconcile: {
                                container.router.dashboardPath.append(AppRoute.reconcile)
                            })
                        BudgetCard(
                            month: model.monthBudget, hidden: hidden,
                            onTap: { container.router.selectedTab = .budget })
                    } else {
                        Label("Riwayat lebih dari 3 bulan tersedia di Premium", systemImage: "lock")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).padding(24)
                            .background(
                                .background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            Section {
                if model.recentLoaded && model.recent.isEmpty {
                    EmptyStateView(
                        title: "Catat transaksi pertama",
                        message: "Pemasukan dan pengeluaranmu akan muncul di sini.",
                        systemImage: "square.and.pencil", actionTitle: "Catat transaksi"
                    ) { container.router.openTransactionForm() }
                    .listRowBackground(Color.clear)
                }
                ForEach(model.recent) { row in
                    Button {
                        container.router.openTransaction(id: row.id)
                    } label: {
                        TransactionRow(transaction: row)
                    }
                    .buttonStyle(.plain)
                }
                if !model.recent.isEmpty {
                    Button("Lihat semua") { container.router.selectedTab = .transactions }
                }
            } header: {
                if !model.recent.isEmpty { Text("Transaksi terakhir") }
            }
        }
        .navigationTitle("Beranda")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { SyncBadge() } }
        .refreshable { await container.scheduler.syncNow() }
        .overlay(alignment: .bottomTrailing) { AddTransactionButton() }
        .task { await model.observeStatic() }
    }
}
