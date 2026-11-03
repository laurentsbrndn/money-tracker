/// Filters of the history list (APP_FLOWS Flow 4): type, account, category, allocation, date
/// range, and search text (note and source).
struct TransactionFilter: Hashable, Sendable {
    var type: String?
    var accountId: String?
    var categoryId: String?
    var allocation: String?
    var from: CivilDate?
    var to: CivilDate?
    var query = ""

    /// Number of filters set (search text not counted), for the badge.
    var activeCount: Int {
        [type, accountId, categoryId, allocation].compactMap { $0 }.count
            + [from, to].compactMap { $0 }.count
    }

    var isEmpty: Bool {
        activeCount == 0 && query.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
