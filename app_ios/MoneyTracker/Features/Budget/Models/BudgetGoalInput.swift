/// A goal as typed in the form; valid when the three percentages are 0-100 and add up to 100
/// (BUSINESS_RULES §6).
struct BudgetGoalInput: Sendable, Equatable {
    var needs: Int
    var wants: Int
    var savings: Int
    var plannedIncome: Int64?

    /// The default split of a new account (BUSINESS_RULES §2.2).
    static let standard = BudgetGoalInput(needs: 50, wants: 30, savings: 20, plannedIncome: nil)

    /// Presets offered next to the form (APP_FLOWS Flow 6 step 1).
    static let presets: [(needs: Int, wants: Int, savings: Int)] = [
        (50, 30, 20), (60, 20, 20), (40, 30, 30),
    ]

    var total: Int { needs + wants + savings }

    var isValid: Bool {
        total == 100 && [needs, wants, savings].allSatisfy { (0...100).contains($0) }
    }
}
