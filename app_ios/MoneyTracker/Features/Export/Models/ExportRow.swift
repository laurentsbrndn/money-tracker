/// One transaction of an export, with account and category names already resolved. `amount` is
/// whole rupiah, signed only for adjustments.
struct ExportRow: Sendable, Equatable {
    var date: CivilDate
    var type: TransactionType
    var amount: Int64
    var accountName: String
    var toAccountName: String?
    var categoryName: String?
    var note: String?
}
