/// What every report is computed from: the local database only, so reports work offline
/// (API.md §5, APP_FLOWS Flow 8).
struct ReportInputs: Sendable {
    var accounts: [Account] = []
    var transactions: [Transaction] = []
    var goals: [BudgetGoal] = []
}
