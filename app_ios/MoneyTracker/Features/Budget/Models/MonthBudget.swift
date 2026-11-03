/// The budget of one month with the goal in force and the date it was computed for.
struct MonthBudget: Sendable, Equatable {
    var month: YearMonth
    var asOf: CivilDate
    var budget: Budget
    /// The goal in force for `month`; nil while none has been set.
    var goal: BudgetGoal?

    func result(of allocation: Allocation) -> AllocationResult {
        switch allocation {
        case .needs: budget.needs
        case .wants: budget.wants
        case .savings: budget.savings
        }
    }

    func pct(of allocation: Allocation) -> Int64 {
        switch allocation {
        case .needs: goal?.needsPct ?? 0
        case .wants: goal?.wantsPct ?? 0
        case .savings: goal?.savingsPct ?? 0
        }
    }

    /// Computes the budget of `month` from the stored rows (BUSINESS_RULES §4.5).
    static func compute(
        accounts: [Account], transactions: [Transaction], goals: [BudgetGoal], month: YearMonth,
        asOf: CivilDate
    ) -> MonthBudget {
        let goal = DomainRules.effectiveGoal(goals, month: month)
        let budget = DomainRules.computeBudget(
            accounts: accounts, transactions: transactions, goal: goal, month: month, asOf: asOf)
        return MonthBudget(month: month, asOf: asOf, budget: budget, goal: goal)
    }
}
