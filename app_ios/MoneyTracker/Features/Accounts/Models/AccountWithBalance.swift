/// An account with its expected balance as of today (BUSINESS_RULES §4.2).
struct AccountWithBalance: Identifiable, Equatable {
    let account: AccountRecord
    let expectedBalance: Int64

    var id: String { account.id }
}
