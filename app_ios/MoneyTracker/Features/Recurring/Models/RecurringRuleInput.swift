/// A recurring rule as typed in the form: the transaction template and the schedule
/// (BUSINESS_RULES §5, DATA_MODEL §5).
struct RecurringRuleInput: Sendable {
    /// `income`, `expense`, or `transfer`.
    var type: String
    var amount: Int64?
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var source: String?
    var note: String?
    var frequency: RecurringFrequency
    var intervalCount: Int
    /// ISO weekday, for weekly rules.
    var dayOfWeek: Int?
    /// For monthly and yearly rules.
    var dayOfMonth: Int?
    /// For yearly rules.
    var monthOfYear: Int?
    var startDate: CivilDate
    var endDate: CivilDate?
    /// `auto` or `confirm`.
    var mode: String
}
