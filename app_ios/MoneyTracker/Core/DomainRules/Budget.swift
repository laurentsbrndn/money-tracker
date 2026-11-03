/// Budget outcome of one bucket (needs, wants, or savings).
struct AllocationResult: Sendable, Equatable {
    var goalAmount: Int64
    var actual: Int64
    /// `actual` as basis points of the basis (1941 = 19,41%); nil when the basis is 0.
    var actualBP: Int64?
    var remaining: Int64
}

/// The budget of one month (§4.5).
struct Budget: Sendable, Equatable {
    var basis: Int64
    var needs: AllocationResult
    var wants: AllocationResult
    var savings: AllocationResult
    var unallocated: Int64
}

extension DomainRules {
    /// The goal in force for `month`: the non-deleted goal with the largest effective month
    /// that is not after `month`.
    static func effectiveGoal(_ goals: [BudgetGoal], month: YearMonth) -> BudgetGoal? {
        var best: BudgetGoal?
        for goal in goals where !goal.isDeleted && goal.effectiveMonth <= month {
            if best == nil || goal.effectiveMonth > best!.effectiveMonth {
                best = goal
            }
        }
        return best
    }

    /// §4.5 for `month`.
    ///
    /// Whether an account is a savings account is read from `accounts` at call time, so
    /// changing an account's type recomputes history. A transfer to or from an unknown account
    /// counts as a non-savings account. With no goal (`goal` nil) all percentages are 0.
    static func computeBudget(
        accounts: [Account], transactions: [Transaction], goal: BudgetGoal?, month: YearMonth,
        asOf: CivilDate
    ) -> Budget {
        var isSavings: [String: Bool] = [:]
        for account in accounts {
            isSavings[account.id] = account.type == .savings
        }

        var income: Int64 = 0
        var needs: Int64 = 0
        var wants: Int64 = 0
        var savingsExpense: Int64 = 0
        var savingsTransfer: Int64 = 0
        for tx in transactions where counts(tx, asOf: asOf) && month.contains(tx.date) {
            switch tx.type {
            case .income:
                income += tx.amount
            case .expense:
                switch tx.allocation {
                case .needs: needs += tx.amount
                case .wants: wants += tx.amount
                case .savings: savingsExpense += tx.amount
                case nil: break
                }
            case .transfer:
                let from = isSavings[tx.accountID] ?? false
                let to = tx.toAccountID.flatMap { isSavings[$0] } ?? false
                if !from && to {
                    savingsTransfer += tx.amount
                } else if from && !to {
                    savingsTransfer -= tx.amount
                }
            case .adjustment:
                break
            }
        }
        let savings = savingsExpense + savingsTransfer

        var planned: Int64 = 0
        var needsPct: Int64 = 0
        var wantsPct: Int64 = 0
        var savingsPct: Int64 = 0
        if let goal {
            planned = goal.plannedIncome ?? 0
            needsPct = goal.needsPct
            wantsPct = goal.wantsPct
            savingsPct = goal.savingsPct
        }
        let basis = max(planned, income)

        return Budget(
            basis: basis,
            needs: allocationResult(basis: basis, pct: needsPct, actual: needs),
            wants: allocationResult(basis: basis, pct: wantsPct, actual: wants),
            savings: allocationResult(basis: basis, pct: savingsPct, actual: savings),
            unallocated: basis - needs - wants - savings)
    }

    private static func allocationResult(basis: Int64, pct: Int64, actual: Int64)
        -> AllocationResult
    {
        let goalAmount = roundHalfUp(basis * pct, 100)
        return AllocationResult(
            goalAmount: goalAmount,
            actual: actual,
            actualBP: basis != 0 ? roundHalfUp(actual * 10000, basis) : nil,
            remaining: goalAmount - actual)
    }
}
