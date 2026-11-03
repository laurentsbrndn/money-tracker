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

// MARK: - Warnings and breakdown

/// Warning thresholds of §4.5, in percent of `goalAmount`.
let budgetWarnPercent = 80
let budgetLimitPercent = 100

/// The expense of one category in a month; `categoryID` is nil for an expense without a
/// category.
struct CategoryTotal: Sendable, Equatable {
    var categoryID: String?
    var amount: Int64
}

/// What makes up one bucket of the budget (APP_FLOWS Flow 6, "rincian per kategori").
struct AllocationBreakdown: Sendable, Equatable {
    /// Expenses of the bucket grouped by category, largest first (§4.6).
    var categories: [CategoryTotal]
    /// Net transfers into savings accounts; 0 for needs and wants. Together with the category
    /// totals it adds up to `actual` of `computeBudget`.
    var transferNet: Int64

    var total: Int64 { categories.reduce(transferNet) { $0 + $1.amount } }
}

extension DomainRules {
    /// The highest warning threshold (80 or 100) that `actual` has reached for a bucket with
    /// `goalAmount`, or nil. A goal of 0 never warns. Integer arithmetic only:
    /// `actual * 100 >= goalAmount * threshold`.
    static func budgetAlertLevel(goalAmount: Int64, actual: Int64) -> Int? {
        guard goalAmount > 0 else { return nil }
        if actual * 100 >= goalAmount * Int64(budgetLimitPercent) { return budgetLimitPercent }
        if actual * 100 >= goalAmount * Int64(budgetWarnPercent) { return budgetWarnPercent }
        return nil
    }

    /// The categories behind `allocation` in `month`, from the same transactions and rules as
    /// `computeBudget`.
    static func computeAllocationBreakdown(
        accounts: [Account], transactions: [Transaction], allocation: Allocation,
        month: YearMonth, asOf: CivilDate
    ) -> AllocationBreakdown {
        var isSavings: [String: Bool] = [:]
        for account in accounts { isSavings[account.id] = account.type == .savings }

        var byCategory: [String?: Int64] = [:]
        var transferNet: Int64 = 0
        for tx in transactions where counts(tx, asOf: asOf) && month.contains(tx.date) {
            switch tx.type {
            case .expense:
                if tx.allocation == allocation {
                    byCategory[tx.categoryID, default: 0] += tx.amount
                }
            case .transfer:
                if allocation == .savings {
                    let from = isSavings[tx.accountID] ?? false
                    let to = tx.toAccountID.flatMap { isSavings[$0] } ?? false
                    if !from && to {
                        transferNet += tx.amount
                    } else if from && !to {
                        transferNet -= tx.amount
                    }
                }
            case .income, .adjustment:
                break
            }
        }
        let categories = byCategory.map { CategoryTotal(categoryID: $0.key, amount: $0.value) }
            .sorted {
                if $0.amount != $1.amount { return $0.amount > $1.amount }
                return ($0.categoryID ?? "") < ($1.categoryID ?? "")
            }
        return AllocationBreakdown(categories: categories, transferNet: transferNet)
    }
}
