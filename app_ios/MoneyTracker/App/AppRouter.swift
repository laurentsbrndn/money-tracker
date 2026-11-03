import Observation
import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case dashboard
    case transactions
    case accounts
    case budget
    case more
}

/// Selected tab and one navigation path per tab.
@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .dashboard

    var dashboardPath = NavigationPath()
    var transactionsPath = NavigationPath()
    var accountsPath = NavigationPath()
    var budgetPath = NavigationPath()
    var morePath = NavigationPath()
}
