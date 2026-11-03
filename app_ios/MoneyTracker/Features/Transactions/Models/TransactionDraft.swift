/// What the entry form collects before saving (APP_FLOWS Flow 3). `existing` is set when editing.
struct TransactionDraft: Sendable {
    /// `income`, `expense`, or `transfer`.
    var type: String
    var amount: Int64?
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var source: String?
    var note: String?
    var date: CivilDate
    /// Admin fee of a transfer, saved as its own linked expense.
    var fee: Int64?
    var existing: TransactionRecord?
}
