import Foundation
import Observation

/// The monthly dashboard (APP_FLOWS Flow 2): month picker, summary, actual money, the difference
/// card, the budget card, and the latest transactions. Every figure comes from `DomainRules`.
@Observable
@MainActor
final class DashboardViewModel {
    var month = YearMonth(containing: UserClock.today())
    private(set) var accounts: [AccountRecord] = []
    /// The full history: the formulas pick the month themselves, and the opening total of the
    /// summary needs everything before it.
    private(set) var allTransactions: [TransactionRecord] = []
    private(set) var snapshots: [BalanceSnapshotRecord] = []
    private(set) var goals: [BudgetGoalRecord] = []
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
            accounts: accounts.map(\.domain), transactions: allTransactions.map(\.domain),
            month: month, asOf: UserClock.today())
    }

    /// Real balances against the recorded ones as of today (not the selected month).
    var overview: ReconcileOverview {
        .compute(
            accounts: accounts, transactions: allTransactions, snapshots: snapshots,
            asOf: UserClock.today())
    }

    /// The budget of the selected month.
    var monthBudget: MonthBudget {
        MonthBudget.compute(
            accounts: accounts.map(\.domain), transactions: allTransactions.map(\.domain),
            goals: goals.map(\.domain), month: month, asOf: UserClock.today())
    }

    /// Accounts, history, snapshots, goals, the latest five transactions, and the entitlement.
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
                await forEachValue(self.database.observeAllTransactions()) {
                    self.allTransactions = $0
                }
            },
            { await forEachValue(self.database.observeAllSnapshots()) { self.snapshots = $0 } },
            { await forEachValue(self.database.observeBudgetGoals()) { self.goals = $0 } },
            {
                await forEachValue(self.database.observeSyncState()) {
                    self.isPremium = PlanLimits.isPremium(
                        entitlementJSON: $0[SyncStateKey.entitlement], now: Date())
                }
            },
        ])
    }
}
