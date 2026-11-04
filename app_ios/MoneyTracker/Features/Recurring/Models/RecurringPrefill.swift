/// What the transaction form hands to the recurring form when the user taps "Jadikan berulang"
/// (APP_FLOWS Flow 10): the transaction becomes the template, and its date the first occurrence.
struct RecurringPrefill: Hashable, Sendable {
    var type: String
    var startDate: CivilDate
    var amount: Int64?
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var source: String?
    var note: String?
}
