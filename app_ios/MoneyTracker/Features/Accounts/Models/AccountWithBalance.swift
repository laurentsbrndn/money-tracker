/// An account with its expected balance as of today (BUSINESS_RULES §4.2) and, when it counts
/// towards the total, its reconciliation against the latest real balance (§4.4).
struct AccountWithBalance: Identifiable, Equatable {
    let account: AccountRecord
    let expectedBalance: Int64
    var reconciliation: AccountReconciliation?

    var id: String { account.id }
}
