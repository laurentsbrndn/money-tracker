import Observation

/// Cocokkan saldo (APP_FLOWS Flow 5): enter the real balance per account, see the difference,
/// then record what was missed, adjust, or leave it. All numbers come from `DomainRules`.
@Observable
@MainActor
final class ReconcileViewModel {
    private(set) var overview = ReconcileOverview()
    private(set) var loaded = false
    private(set) var busy = false
    var errorMessage: String?

    /// Typed real balances by account id (formatted text, may start with `-`).
    var inputs: [String: String] = [:]
    /// Accounts whose real balance was entered in this visit.
    private(set) var reconciled: Set<String> = []
    /// Accounts the user chose "Nanti saja" for.
    private(set) var deferred: Set<String> = []
    /// Signed adjustment made per account in this visit.
    private(set) var adjusted: [String: Int64] = [:]

    private var accounts: [AccountRecord] = []
    private var transactions: [TransactionRecord] = []
    private var snapshots: [BalanceSnapshotRecord] = []
    private let database: AppDatabase
    private let repository: ReconciliationRepository

    init(container: AppContainer) {
        database = container.database
        repository = container.reconciliation
    }

    var reconciledItems: [ReconcileItem] { overview.active.filter { reconciled.contains($0.id) } }

    var matchedCount: Int {
        reconciledItems.filter { $0.result.status == .matched }.count
    }

    var adjustedTotal: Int64 { adjusted.values.reduce(0, +) }

    func start() async {
        await concurrently([
            {
                await forEachValue(self.database.observeAccounts()) {
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
        overview = .compute(
            accounts: accounts, transactions: transactions, snapshots: snapshots,
            asOf: UserClock.today())
        loaded = true
    }

    /// Saves the entered balances as today's snapshots.
    func submit() async {
        var balances: [String: Int64] = [:]
        for (id, text) in inputs where !reconciled.contains(id) {
            if let value = MoneyFormatter.value(of: text, allowNegative: true) {
                balances[id] = value
            }
        }
        guard !balances.isEmpty else {
            errorMessage = String(localized: "Isi saldo asli minimal satu akun.")
            return
        }
        busy = true
        defer { busy = false }
        do {
            let saved = try await repository.saveSnapshots(balances)
            reconciled.formUnion(saved)
            deferred.subtract(saved)
            for id in saved { inputs[id] = nil }
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func postpone(_ accountId: String) { deferred.insert(accountId) }
    func undefer(_ accountId: String) { deferred.remove(accountId) }

    /// Books an adjustment for the account's current difference; the amount is re-read from the
    /// database now.
    func adjust(_ accountId: String) async {
        busy = true
        defer { busy = false }
        do {
            let amount = try await repository.adjustCurrentDifference(
                accountId: accountId, note: String(localized: "Selisih tidak tercatat"))
            if amount != 0 { adjusted[accountId, default: 0] += amount }
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
