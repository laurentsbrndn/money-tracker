import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case dashboard
    case transactions
    case accounts
    case budget
    case more
}

/// Screens pushed onto a tab's `NavigationStack`.
enum AppRoute: Hashable {
    case accountDetail(id: String)
    case accountForm(id: String?)
    case categories
    case categoryForm(id: String?, type: String?)
    case profile
    case changePassword
    case syncSettings
    case deleteAccount
}

/// What the transaction form sheet opens with.
struct TransactionFormRequest: Identifiable, Hashable {
    enum Mode: Hashable {
        case new(type: String, fromAccountId: String?, amount: Int64?)
        case edit(id: String)
    }

    let id = UUID()
    let mode: Mode
}

/// Selected tab, one navigation path per tab, and the sheets any screen can ask for.
@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .dashboard

    var dashboardPath = NavigationPath()
    var transactionsPath = NavigationPath()
    var accountsPath = NavigationPath()
    var budgetPath = NavigationPath()
    var morePath = NavigationPath()

    /// The login screen over a session that needs a fresh login (data stays usable).
    var showReLogin = false
    var showVerifyEmail = false
    var transactionForm: TransactionFormRequest?
    /// A filter another screen wants the transactions tab to open with (account detail → "Lihat semua").
    var pendingTransactionFilter: TransactionFilter?

    /// Back to a clean state after signing out, so the next user does not land on the previous
    /// user's screens.
    func reset() {
        selectedTab = .dashboard
        dashboardPath = NavigationPath()
        transactionsPath = NavigationPath()
        accountsPath = NavigationPath()
        budgetPath = NavigationPath()
        morePath = NavigationPath()
        showReLogin = false
        showVerifyEmail = false
        transactionForm = nil
        pendingTransactionFilter = nil
    }

    func push(_ route: AppRoute) {
        switch selectedTab {
        case .dashboard: dashboardPath.append(route)
        case .transactions: transactionsPath.append(route)
        case .accounts: accountsPath.append(route)
        case .budget: budgetPath.append(route)
        case .more: morePath.append(route)
        }
    }

    func openSyncSettings() {
        selectedTab = .more
        morePath = NavigationPath([AppRoute.syncSettings])
    }

    func openTransactionForm(
        type: String = "expense", fromAccountId: String? = nil, amount: Int64? = nil
    ) {
        transactionForm = TransactionFormRequest(
            mode: .new(type: type, fromAccountId: fromAccountId, amount: amount))
    }

    func showTransactions(filter: TransactionFilter) {
        pendingTransactionFilter = filter
        selectedTab = .transactions
    }

    func openTransaction(id: String) {
        transactionForm = TransactionFormRequest(mode: .edit(id: id))
    }
}
