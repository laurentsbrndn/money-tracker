package domainrules

import "moneytracker/internal/platform/civil"

// counts reports whether tx takes part in any formula as of asOf (docs/BUSINESS_RULES.md §3):
// not deleted, posted, and dated on or before asOf.
func counts(tx Transaction, asOf civil.Date) bool {
	return !tx.Deleted && tx.Status == StatusPosted && !tx.Date.After(asOf)
}

// ExpectedBalance is E(A, d): the opening balance plus every counted transaction of the
// account dated within [opening_date, d] (docs/BUSINESS_RULES.md §4.2).
func ExpectedBalance(account Account, txs []Transaction, d civil.Date) int64 {
	balance := account.OpeningBalance
	for _, tx := range txs {
		if !counts(tx, d) || tx.Date.Before(account.OpeningDate) {
			continue
		}
		switch tx.Type {
		case TxIncome:
			if tx.AccountID == account.ID {
				balance += tx.Amount
			}
		case TxExpense:
			if tx.AccountID == account.ID {
				balance -= tx.Amount
			}
		case TxTransfer:
			if tx.AccountID == account.ID {
				balance -= tx.Amount
			}
			if tx.ToAccountID == account.ID {
				balance += tx.Amount
			}
		case TxAdjustment:
			if tx.AccountID == account.ID {
				balance += tx.Amount
			}
		}
	}
	return balance
}

// inTotal reports whether the account is part of totals: included and not deleted.
// Archived accounts still count.
func inTotal(a Account) bool {
	return a.IncludeInTotal && !a.Deleted
}

// ExpectedTotal sums E(A, d) over the accounts that are part of the total.
func ExpectedTotal(accounts []Account, txs []Transaction, d civil.Date) int64 {
	var total int64
	for _, a := range accounts {
		if inTotal(a) {
			total += ExpectedBalance(a, txs, d)
		}
	}
	return total
}

// MonthlySummary is the income/expense summary of one month.
type MonthlySummary struct {
	Income       int64
	Expense      int64
	Surplus      int64
	OpeningTotal int64
}

// ComputeMonthlySummary computes docs/BUSINESS_RULES.md §4.1. Transfers and adjustments are
// neither income nor expense. OpeningTotal is the expected total on the last day of the
// previous month.
func ComputeMonthlySummary(accounts []Account, txs []Transaction, month YearMonth, asOf civil.Date) MonthlySummary {
	var s MonthlySummary
	for _, tx := range txs {
		if !counts(tx, asOf) || !month.Contains(tx.Date) {
			continue
		}
		switch tx.Type {
		case TxIncome:
			s.Income += tx.Amount
		case TxExpense:
			s.Expense += tx.Amount
		}
	}
	s.Surplus = s.Income - s.Expense
	s.OpeningTotal = ExpectedTotal(accounts, txs, month.AddMonths(-1).Last())
	return s
}
