import SwiftUI

struct MainTabView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var router = container.router

        TabView(selection: $router.selectedTab) {
            Tab("Beranda", systemImage: "house", value: AppTab.dashboard) {
                NavigationStack(path: $router.dashboardPath) {
                    TabPlaceholderView(title: "Beranda")
                }
            }
            Tab("Transaksi", systemImage: "list.bullet", value: AppTab.transactions) {
                NavigationStack(path: $router.transactionsPath) {
                    TabPlaceholderView(title: "Transaksi")
                }
            }
            Tab("Akun", systemImage: "creditcard", value: AppTab.accounts) {
                NavigationStack(path: $router.accountsPath) {
                    TabPlaceholderView(title: "Akun")
                }
            }
            Tab("Budget", systemImage: "chart.pie", value: AppTab.budget) {
                NavigationStack(path: $router.budgetPath) {
                    TabPlaceholderView(title: "Budget")
                }
            }
            Tab("Lainnya", systemImage: "ellipsis", value: AppTab.more) {
                NavigationStack(path: $router.morePath) {
                    TabPlaceholderView(title: "Lainnya")
                }
            }
        }
    }
}

private struct TabPlaceholderView: View {
    let title: LocalizedStringKey

    var body: some View {
        ContentUnavailableView("Segera hadir", systemImage: "hammer")
            .navigationTitle(title)
    }
}
