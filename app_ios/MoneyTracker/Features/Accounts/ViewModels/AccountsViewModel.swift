import Observation

/// The accounts tab (APP_FLOWS Flow 5): the expected total and the accounts by type. Balances
/// come from `DomainRules`, never from the view.
@Observable
@MainActor
final class AccountsViewModel {
    private(set) var items: [AccountWithBalance] = []
    private(set) var expectedTotal: Int64 = 0
    private(set) var overview = ReconcileOverview()
    private(set) var loaded = false

    private var accounts: [AccountRecord] = []
    private var transactions: [TransactionRecord] = []
    private var snapshots: [BalanceSnapshotRecord] = []
    private let database: AppDatabase
    private let repository: AccountsRepository

    init(container: AppContainer) {
        database = container.database
        repository = container.accounts
    }

    var active: [AccountWithBalance] { items.filter { $0.account.archivedAt == nil } }
    var archived: [AccountWithBalance] { items.filter { $0.account.archivedAt != nil } }

    func start() async {
        await concurrently([
            {
                await forEachValue(self.repository.observeAll()) {
                    self.accounts = $0
                    self.recompute()
                }
            },
            {
                await forEachValue(self.database.observeAllTransactions()) {
                    self.transactions = $0
                    self.recompute()
                }
            },
            {
                await forEachValue(self.database.observeAllSnapshots()) {
                    self.snapshots = $0
                    self.recompute()
                }
            },
        ])
    }

    private func recompute() {
        let today = UserClock.today()
        let domainTransactions = transactions.map(\.domain)
        overview = .compute(
            accounts: accounts, transactions: transactions, snapshots: snapshots, asOf: today)
        items = accounts.map {
            AccountWithBalance(
                account: $0,
                expectedBalance: DomainRules.expectedBalance(
                    account: $0.domain, transactions: domainTransactions, on: today),
                reconciliation: overview.item(for: $0.id)?.result)
        }
        expectedTotal = DomainRules.expectedTotal(
            accounts: accounts.map(\.domain), transactions: domainTransactions, on: today)
        loaded = true
    }
}
