import Foundation
import Observation

/// The monthly dashboard (APP_FLOWS Flow 2): month picker, summary, and the latest transactions.
/// The cards for actual money, differences, and budget arrive in Fase 2.
@Observable
@MainActor
final class DashboardViewModel {
    var month = YearMonth(containing: UserClock.today())
    private(set) var accounts: [AccountRecord] = []
    private(set) var monthTransactions: [TransactionRecord] = []
    private(set) var recent: [TransactionRecord] = []
    private(set) var recentLoaded = false
    private(set) var isPremium = false

    private let database: AppDatabase
    private let transactionsRepository: TransactionsRepository
    private let accountsRepository: AccountsRepository

    init(container: AppContainer) {
        database = container.database
        transactionsRepository = container.transactions
        accountsRepository = container.accounts
    }

    var currentMonth: YearMonth { YearMonth(containing: UserClock.today()) }

    /// The oldest month a free user may open: the current month plus the two before it
    /// (BUSINESS_RULES §7).
    var oldestFreeMonth: YearMonth { currentMonth.adding(months: -2) }

    func canView(_ month: YearMonth) -> Bool { isPremium || month >= oldestFreeMonth }

    var canGoPrevious: Bool { true }
    var canGoNext: Bool { month < currentMonth }

    func previousMonth() { month = month.adding(months: -1) }
    func nextMonth() { if canGoNext { month = month.adding(months: 1) } }

    var summary: MonthlySummary {
        DomainRules.computeMonthlySummary(
            accounts: accounts.map(\.domain), transactions: monthTransactions.map(\.domain),
            month: month, asOf: UserClock.today())
    }

    /// Accounts, the latest five transactions, and the entitlement: independent of the month.
    func observeStatic() async {
        await concurrently([
            { await forEachValue(self.accountsRepository.observeAll()) { self.accounts = $0 } },
            {
                await forEachValue(
                    self.transactionsRepository.observe(TransactionFilter(), limit: 5)
                ) {
                    self.recent = $0
                    self.recentLoaded = true
                }
            },
            {
                await forEachValue(self.database.observeSyncState()) {
                    self.isPremium = PlanLimits.isPremium(
                        entitlementJSON: $0[SyncStateKey.entitlement], now: Date())
                }
            },
        ])
    }

    /// Transactions of the selected month; restarted when the month changes.
    func observeMonth() async {
        guard canView(month) else {
            monthTransactions = []
            return
        }
        await forEachValue(database.observeTransactions(in: month)) { self.monthTransactions = $0 }
    }
}
