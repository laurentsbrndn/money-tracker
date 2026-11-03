import Observation

/// Budget tab (APP_FLOWS Flow 6): goal against actual per bucket, what is not yet allocated,
/// and the per-category breakdown behind each bucket. Every figure comes from `DomainRules`.
@Observable
@MainActor
final class BudgetViewModel {
    var month: YearMonth
    private(set) var loaded = false

    private var accounts: [AccountRecord] = []
    private var transactions: [TransactionRecord] = []
    private var goals: [BudgetGoalRecord] = []
    private let database: AppDatabase
    private let repository: BudgetRepository

    init(container: AppContainer) {
        database = container.database
        repository = container.budget
        month = YearMonth(containing: UserClock.today())
    }

    var currentMonth: YearMonth { YearMonth(containing: UserClock.today()) }
    var canGoNext: Bool { month < currentMonth }

    func previousMonth() { month = month.adding(months: -1) }
    func nextMonth() { if canGoNext { month = month.adding(months: 1) } }

    var monthBudget: MonthBudget {
        MonthBudget.compute(
            accounts: accounts.map(\.domain), transactions: transactions.map(\.domain),
            goals: goals.map(\.domain), month: month, asOf: UserClock.today())
    }

    /// The categories behind `allocation` in the selected month.
    func breakdown(for allocation: Allocation) -> AllocationBreakdown {
        DomainRules.computeAllocationBreakdown(
            accounts: accounts.map(\.domain), transactions: transactions.map(\.domain),
            allocation: allocation, month: month, asOf: UserClock.today())
    }

    func start() async {
        await concurrently([
            {
                await forEachValue(self.database.observeAccounts()) {
                    self.accounts = $0
                    self.loaded = true
                }
            },
            {
                await forEachValue(self.database.observeAllTransactions()) {
                    self.transactions = $0
                }
            },
            { await forEachValue(self.repository.observeGoals()) { self.goals = $0 } },
        ])
    }
}
