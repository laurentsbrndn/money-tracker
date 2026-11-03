import Observation

/// One account: balance, latest transactions, snapshots, and archive/delete (APP_FLOWS Flow 5).
@Observable
@MainActor
final class AccountDetailViewModel {
    let accountId: String
    private(set) var account: AccountRecord?
    private(set) var expectedBalance: Int64 = 0
    private(set) var recent: [TransactionRecord] = []
    private(set) var snapshots: [BalanceSnapshotRecord] = []
    private(set) var loaded = false
    var errorMessage: String?
    var notice: String?

    private var transactions: [TransactionRecord] = []
    private let database: AppDatabase
    private let repository: AccountsRepository
    private let transactionsRepository: TransactionsRepository

    init(container: AppContainer, accountId: String) {
        self.accountId = accountId
        database = container.database
        repository = container.accounts
        transactionsRepository = container.transactions
    }

    func start() async {
        let filter = TransactionFilter(accountId: accountId)
        await concurrently([
            {
                await forEachValue(self.repository.observe(id: self.accountId)) {
                    self.account = $0
                    self.loaded = true
                    self.recomputeBalance()
                }
            },
            {
                await forEachValue(self.database.observeAllTransactions()) {
                    self.transactions = $0
                    self.recomputeBalance()
                }
            },
            {
                await forEachValue(self.transactionsRepository.observe(filter, limit: 30)) {
                    self.recent = $0
                }
            },
            {
                await forEachValue(self.repository.observeSnapshots(accountId: self.accountId)) {
                    self.snapshots = $0
                }
            },
        ])
    }

    private func recomputeBalance() {
        guard let account else { return }
        expectedBalance = DomainRules.expectedBalance(
            account: account.domain, transactions: transactions.map(\.domain), on: UserClock.today()
        )
    }

    func archive() async {
        guard let account else { return }
        await run(String(localized: "Akun diarsipkan")) {
            try await self.repository.setArchived(account, archived: true)
        }
    }

    func unarchive() async {
        guard let account else { return }
        await run(String(localized: "Akun diaktifkan lagi")) {
            try await self.repository.setArchived(account, archived: false)
        }
    }

    /// Returns true when the account is gone.
    func delete() async -> Bool {
        do {
            try await repository.delete(accountId)
            return true
        } catch {
            errorMessage = ErrorMessages.describe(error)
            return false
        }
    }

    private func run(_ success: String, _ action: () async throws -> Void) async {
        do {
            try await action()
            notice = success
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
