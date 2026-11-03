/// An account with its reconciliation result as of today (BUSINESS_RULES §4.4), both produced
/// by `DomainRules`.
struct ReconcileItem: Identifiable, Equatable {
    let account: AccountRecord
    let result: AccountReconciliation

    var id: String { account.id }
}

/// Everything the reconcile screen, the dashboard cards, and the account list show.
struct ReconcileOverview: Equatable {
    /// Accounts that count towards the total (archived ones included), in list order.
    var items: [ReconcileItem] = []
    var totals = ReconciliationTotals()

    /// The accounts the user is asked about: not archived.
    var active: [ReconcileItem] { items.filter { $0.account.archivedAt == nil } }

    var matchedCount: Int { count(.matched) }
    var mismatchCount: Int { count(.mismatch) }
    var staleCount: Int { count(.stale) }

    /// The newest snapshot date over all accounts, when the real balances were last updated; nil
    /// if there is no snapshot.
    var lastUpdated: CivilDate? { items.compactMap(\.result.latestSnapshotDate).max() }

    func item(for accountID: String) -> ReconcileItem? { items.first { $0.id == accountID } }

    private func count(_ status: ReconciliationStatus) -> Int {
        items.filter { $0.result.status == status }.count
    }

    /// §4.2–§4.4 as of `asOf`, over the full history.
    static func compute(
        accounts: [AccountRecord], transactions: [TransactionRecord],
        snapshots: [BalanceSnapshotRecord], asOf: CivilDate
    ) -> ReconcileOverview {
        let result = DomainRules.reconcile(
            accounts: accounts.map(\.domain), transactions: transactions.map(\.domain),
            snapshots: snapshots.map(\.domain), asOf: asOf)
        let byID = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ReconcileOverview(
            items: result.accounts.compactMap { entry in
                byID[entry.accountID].map { ReconcileItem(account: $0, result: entry) }
            },
            totals: result.totals)
    }
}
