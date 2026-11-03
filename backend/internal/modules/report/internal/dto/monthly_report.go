// Package dto holds the response bodies of the report endpoints (contracts/openapi.yaml).
package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/ledger"
	"moneytracker/internal/modules/report/internal/service"
)

// MonthlySummary is schema MonthlySummary.
type MonthlySummary struct {
	Income       int64 `json:"income"`
	Expense      int64 `json:"expense"`
	Surplus      int64 `json:"surplus"`
	OpeningTotal int64 `json:"opening_total"`
}

// AccountReconciliation is schema AccountReconciliation.
type AccountReconciliation struct {
	ID                   uuid.UUID `json:"id"`
	ExpectedBalance      int64     `json:"expected_balance"`
	LatestSnapshotAmount int64     `json:"latest_snapshot_amount"`
	LatestSnapshotDate   string    `json:"latest_snapshot_date"`
	Diff                 int64     `json:"diff"`
	Status               string    `json:"status"`
}

// ReportTotals is schema ReportTotals.
type ReportTotals struct {
	ExpectedTotal  int64 `json:"expected_total"`
	ActualAccounts int64 `json:"actual_accounts"`
	ActualCash     int64 `json:"actual_cash"`
	ActualTotal    int64 `json:"actual_total"`
	DiffTotal      int64 `json:"diff_total"`
}

// BudgetAllocation is schema BudgetAllocation; ActualBP is null when the basis is 0.
type BudgetAllocation struct {
	GoalAmount int64  `json:"goal_amount"`
	Actual     int64  `json:"actual"`
	ActualBP   *int64 `json:"actual_bp"`
	Remaining  int64  `json:"remaining"`
}

// ReportBudget is schema ReportBudget.
type ReportBudget struct {
	Basis       int64            `json:"basis"`
	Needs       BudgetAllocation `json:"needs"`
	Wants       BudgetAllocation `json:"wants"`
	Savings     BudgetAllocation `json:"savings"`
	Unallocated int64            `json:"unallocated"`
}

// CategoryTotal is schema CategoryTotal; CategoryID is null for income without a category.
type CategoryTotal struct {
	CategoryID *uuid.UUID `json:"category_id"`
	Amount     int64      `json:"amount"`
}

// MonthlyReport is schema MonthlyReport.
type MonthlyReport struct {
	MonthlySummary    MonthlySummary          `json:"monthly_summary"`
	Accounts          []AccountReconciliation `json:"accounts"`
	Totals            ReportTotals            `json:"totals"`
	Budget            ReportBudget            `json:"budget"`
	ExpenseByCategory []CategoryTotal         `json:"expense_by_category"`
	IncomeByCategory  []CategoryTotal         `json:"income_by_category"`
}

// noSnapshotDate stands in for the date of an account that has no snapshot (it should not
// happen, docs/BUSINESS_RULES.md §2.3); the schema requires a date.
const noSnapshotDate = "0001-01-01"

// NewMonthlyReport maps the service result to the response body.
func NewMonthlyReport(r service.MonthlyReport) MonthlyReport {
	accounts := make([]AccountReconciliation, 0, len(r.Reconciliation.Accounts))
	for _, a := range r.Reconciliation.Accounts {
		id, _ := uuid.Parse(a.AccountID)
		date := noSnapshotDate
		if a.HasSnapshot {
			date = a.LatestSnapshotDate.String()
		}
		accounts = append(accounts, AccountReconciliation{
			ID:                   id,
			ExpectedBalance:      a.ExpectedBalance,
			LatestSnapshotAmount: a.LatestSnapshotAmount,
			LatestSnapshotDate:   date,
			Diff:                 a.Diff,
			Status:               string(a.Status),
		})
	}
	t := r.Reconciliation.Totals
	return MonthlyReport{
		MonthlySummary: MonthlySummary{
			Income: r.Summary.Income, Expense: r.Summary.Expense,
			Surplus: r.Summary.Surplus, OpeningTotal: r.Summary.OpeningTotal,
		},
		Accounts: accounts,
		Totals: ReportTotals{
			ExpectedTotal: t.ExpectedTotal, ActualAccounts: t.ActualAccounts,
			ActualCash: t.ActualCash, ActualTotal: t.ActualTotal, DiffTotal: t.DiffTotal,
		},
		Budget: ReportBudget{
			Basis:       r.Budget.Basis,
			Needs:       allocation(r.Budget.Needs),
			Wants:       allocation(r.Budget.Wants),
			Savings:     allocation(r.Budget.Savings),
			Unallocated: r.Budget.Unallocated,
		},
		ExpenseByCategory: categoryTotals(r.ExpenseByCategory),
		IncomeByCategory:  categoryTotals(r.IncomeByCategory),
	}
}

func allocation(a domainrules.AllocationResult) BudgetAllocation {
	return BudgetAllocation{GoalAmount: a.GoalAmount, Actual: a.Actual, ActualBP: a.ActualBP, Remaining: a.Remaining}
}

func categoryTotals(in []ledger.CategoryTotal) []CategoryTotal {
	out := make([]CategoryTotal, 0, len(in))
	for _, c := range in {
		out = append(out, CategoryTotal{CategoryID: c.CategoryID, Amount: c.Amount})
	}
	return out
}
