import SwiftUI

struct MainTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Beranda", systemImage: "house", value: AppTab.dashboard) {
                NavigationStack(path: $router.dashboardPath) {
                    HomeView(container: container).routeDestinations(container)
                }
            }
            Tab("Transaksi", systemImage: "list.bullet", value: AppTab.transactions) {
                NavigationStack(path: $router.transactionsPath) {
                    TransactionsView(container: container).routeDestinations(container)
                }
            }
            Tab("Akun", systemImage: "creditcard", value: AppTab.accounts) {
                NavigationStack(path: $router.accountsPath) {
                    AccountsView(container: container).routeDestinations(container)
                }
            }
            Tab("Budget", systemImage: "chart.pie", value: AppTab.budget) {
                NavigationStack(path: $router.budgetPath) {
                    BudgetView(container: container).routeDestinations(container)
                }
            }
            Tab("Lainnya", systemImage: "ellipsis", value: AppTab.more) {
                NavigationStack(path: $router.morePath) {
                    MoreView(container: container).routeDestinations(container)
                }
            }
        }
        .sheet(item: $router.transactionForm) { request in
            TransactionFormView(container: container, request: request)
        }
        .sheet(isPresented: $router.showVerifyEmail) { VerifyEmailView(container: container) }
    }
}

extension View {
    /// The screens any tab can push (`AppRoute`).
    func routeDestinations(_ container: AppContainer) -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .accountDetail(let id): AccountDetailView(container: container, accountId: id)
            case .accountForm(let id): AccountFormView(container: container, accountId: id)
            case .categories: CategoriesView(container: container)
            case .categoryForm(let id, let type):
                CategoryFormView(container: container, categoryId: id, type: type)
            case .profile: ProfileView(container: container)
            case .changePassword: ChangePasswordView(container: container)
            case .syncSettings: SyncSettingsView(container: container)
            case .deleteAccount: DeleteAccountView(container: container)
            case .reconcile: ReconcileView(container: container)
            case .budgetGoal: BudgetGoalView(container: container)
            case .preferences: PreferencesView(container: container)
            case .security: SecurityView(container: container)
            case .securityPin(let mode): PinSetupView(container: container, mode: mode)
            case .notifications: NotificationSettingsView(container: container)
            case .subscription: SubscriptionView()
            case .paywall(let restore): PaywallView(restoreOnOpen: restore)
            case .recurring: RecurringView(container: container)
            case .recurringForm(let id, let prefill):
                RecurringFormView(container: container, ruleId: id, prefill: prefill)
            case .reports: ReportsView(container: container)
            case .export: ExportView(container: container)
            }
        }
    }
}
