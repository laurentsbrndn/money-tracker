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
                    ContentUnavailableView("Segera hadir", systemImage: "hammer")
                        .navigationTitle("Budget")
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
            }
        }
    }
}
