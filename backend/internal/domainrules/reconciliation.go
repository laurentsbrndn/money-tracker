package domainrules

import "moneytracker/internal/platform/civil"

// StaleAfterDays is the age in days beyond which a snapshot is stale: a snapshot taken exactly
// 7 days before asOf is not stale yet (docs/BUSINESS_RULES.md §4.4).
const StaleAfterDays = 7

// ReconciliationStatus classifies an account's latest snapshot.
type ReconciliationStatus string

const (
	ReconciliationMatched  ReconciliationStatus = "matched"
	ReconciliationMismatch ReconciliationStatus = "mismatch"
	ReconciliationStale    ReconciliationStatus = "stale"
)

// AccountReconciliation compares one account's latest snapshot with what the transactions say.
//
// ExpectedBalance is evaluated at asOf; Diff is evaluated at the snapshot date. An account with
// no snapshot (every account should have one, docs/BUSINESS_RULES.md §2.3) is reported stale with
// HasSnapshot false, zero amounts, and zero diff.
type AccountReconciliation struct {
	AccountID            string
	AccountType          AccountType
	ExpectedBalance      int64
	HasSnapshot          bool
	LatestSnapshotAmount int64
	LatestSnapshotDate   civil.Date
	Diff                 int64
	Status               ReconciliationStatus
}

// Totals are the account sums of docs/BUSINESS_RULES.md §4.2–§4.4.
type Totals struct {
	ExpectedTotal  int64
	ActualAccounts int64 // bank, e_wallet, savings
	ActualCash     int64
	ActualTotal    int64
	DiffTotal      int64
}

// Reconciliation is the per-account result plus totals.
type Reconciliation struct {
	Accounts []AccountReconciliation
	Totals   Totals
}

// LatestSnapshot returns the account's newest snapshot on or before asOf: the largest date,
// then the largest UpdatedAt. Deleted snapshots are ignored.
func LatestSnapshot(snapshots []BalanceSnapshot, accountID string, asOf civil.Date) (BalanceSnapshot, bool) {
	var best BalanceSnapshot
	found := false
	for _, s := range snapshots {
		if s.Deleted || s.AccountID != accountID || s.Date.After(asOf) {
			continue
		}
		if !found || s.Date.After(best.Date) || (s.Date.Equal(best.Date) && s.UpdatedAt.After(best.UpdatedAt)) {
			best = s
			found = true
		}
	}
	return best, found
}

// Reconcile computes docs/BUSINESS_RULES.md §4.2–§4.4 for every account that is part of the
// total, in input order.
func Reconcile(accounts []Account, txs []Transaction, snapshots []BalanceSnapshot, asOf civil.Date) Reconciliation {
	var result Reconciliation
	for _, a := range accounts {
		if !inTotal(a) {
			continue
		}
		rec := AccountReconciliation{
			AccountID:       a.ID,
			AccountType:     a.Type,
			ExpectedBalance: ExpectedBalance(a, txs, asOf),
			Status:          ReconciliationStale,
		}

		if snap, ok := LatestSnapshot(snapshots, a.ID, asOf); ok {
			rec.HasSnapshot = true
			rec.LatestSnapshotAmount = snap.Amount
			rec.LatestSnapshotDate = snap.Date
			rec.Diff = snap.Amount - ExpectedBalance(a, txs, snap.Date)
			switch {
			case asOf.DaysSince(snap.Date) > StaleAfterDays:
				rec.Status = ReconciliationStale
			case rec.Diff == 0:
				rec.Status = ReconciliationMatched
			default:
				rec.Status = ReconciliationMismatch
			}

			if a.Type == AccountCash {
				result.Totals.ActualCash += snap.Amount
			} else {
				result.Totals.ActualAccounts += snap.Amount
			}
		}

		result.Totals.ExpectedTotal += rec.ExpectedBalance
		result.Totals.DiffTotal += rec.Diff
		result.Accounts = append(result.Accounts, rec)
	}
	result.Totals.ActualTotal = result.Totals.ActualAccounts + result.Totals.ActualCash
	return result
}
