package domainrules

import "moneytracker/internal/platform/civil"

// AllocationResult is the budget outcome of one bucket (needs, wants, or savings).
type AllocationResult struct {
	GoalAmount int64
	Actual     int64
	// ActualBP is Actual as basis points of the basis (1941 = 19,41%); nil when basis is 0.
	ActualBP  *int64
	Remaining int64
}

// Budget is the budget of one month (docs/BUSINESS_RULES.md §4.5).
type Budget struct {
	Basis       int64
	Needs       AllocationResult
	Wants       AllocationResult
	Savings     AllocationResult
	Unallocated int64
}

// EffectiveGoal returns the goal in force for month: the non-deleted goal with the largest
// EffectiveMonth that is not after month.
func EffectiveGoal(goals []BudgetGoal, month YearMonth) (BudgetGoal, bool) {
	var best BudgetGoal
	found := false
	for _, g := range goals {
		if g.Deleted || g.EffectiveMonth.Compare(month) > 0 {
			continue
		}
		if !found || g.EffectiveMonth.Compare(best.EffectiveMonth) > 0 {
			best = g
			found = true
		}
	}
	return best, found
}

// ComputeBudget computes docs/BUSINESS_RULES.md §4.5 for month.
//
// Whether an account is a savings account is read from accounts at call time, so changing an
// account's type recomputes history. A transfer to or from an unknown account counts as a
// non-savings account. With no goal (found false) all percentages are 0.
func ComputeBudget(accounts []Account, txs []Transaction, goal BudgetGoal, found bool, month YearMonth, asOf civil.Date) Budget {
	isSavings := map[string]bool{}
	for _, a := range accounts {
		isSavings[a.ID] = a.Type == AccountSavings
	}

	var income, needs, wants, savingsExpense, savingsTransfer int64
	for _, tx := range txs {
		if !counts(tx, asOf) || !month.Contains(tx.Date) {
			continue
		}
		switch tx.Type {
		case TxIncome:
			income += tx.Amount
		case TxExpense:
			switch tx.Allocation {
			case AllocationNeeds:
				needs += tx.Amount
			case AllocationWants:
				wants += tx.Amount
			case AllocationSavings:
				savingsExpense += tx.Amount
			case AllocationNone:
			}
		case TxTransfer:
			from, to := isSavings[tx.AccountID], isSavings[tx.ToAccountID]
			switch {
			case !from && to:
				savingsTransfer += tx.Amount
			case from && !to:
				savingsTransfer -= tx.Amount
			}
		}
	}
	savings := savingsExpense + savingsTransfer

	var planned int64
	var needsPct, wantsPct, savingsPct int64
	if found {
		if goal.PlannedIncome != nil {
			planned = *goal.PlannedIncome
		}
		needsPct, wantsPct, savingsPct = goal.NeedsPct, goal.WantsPct, goal.SavingsPct
	}
	basis := max(planned, income)

	return Budget{
		Basis:       basis,
		Needs:       allocationResult(basis, needsPct, needs),
		Wants:       allocationResult(basis, wantsPct, wants),
		Savings:     allocationResult(basis, savingsPct, savings),
		Unallocated: basis - needs - wants - savings,
	}
}

func allocationResult(basis, pct, actual int64) AllocationResult {
	goalAmount := RoundHalfUp(basis*pct, 100)
	result := AllocationResult{
		GoalAmount: goalAmount,
		Actual:     actual,
		Remaining:  goalAmount - actual,
	}
	if basis != 0 {
		bp := RoundHalfUp(actual*10000, basis)
		result.ActualBP = &bp
	}
	return result
}
