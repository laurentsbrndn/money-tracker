// Package domainrules implements the formulas of docs/BUSINESS_RULES.md as pure code:
// no I/O, no database, no clock. Callers pass in already-loaded values.
//
// The inputs are plain value types (not GORM entities) so the same rules work for the report
// module, the recurring cron, and anything else. IDs are opaque strings. Soft-deleted rows are
// flagged with Deleted; rows that are deleted never count.
package domainrules

import (
	"time"

	"moneytracker/internal/platform/civil"
)

// AccountType is accounts.type.
type AccountType string

const (
	AccountBank    AccountType = "bank"
	AccountEWallet AccountType = "e_wallet"
	AccountCash    AccountType = "cash"
	AccountSavings AccountType = "savings"
)

// TransactionType is transactions.type.
type TransactionType string

const (
	TxIncome     TransactionType = "income"
	TxExpense    TransactionType = "expense"
	TxTransfer   TransactionType = "transfer"
	TxAdjustment TransactionType = "adjustment"
)

// TransactionStatus is transactions.status.
type TransactionStatus string

const (
	StatusPosted              TransactionStatus = "posted"
	StatusPendingConfirmation TransactionStatus = "pending_confirmation"
)

// Allocation is the needs/wants/savings bucket of an expense.
type Allocation string

const (
	AllocationNone    Allocation = ""
	AllocationNeeds   Allocation = "needs"
	AllocationWants   Allocation = "wants"
	AllocationSavings Allocation = "savings"
)

// Account holds the account fields the rules need.
type Account struct {
	ID             string
	Type           AccountType
	OpeningBalance int64
	OpeningDate    civil.Date
	IncludeInTotal bool
	Deleted        bool
}

// Transaction holds the transaction fields the rules need.
// ToAccountID is empty unless Type is TxTransfer; Allocation is empty unless Type is TxExpense.
type Transaction struct {
	ID          string
	Type        TransactionType
	Status      TransactionStatus
	Date        civil.Date
	Amount      int64 // signed for TxAdjustment, positive otherwise
	AccountID   string
	ToAccountID string
	Allocation  Allocation
	Deleted     bool
}

// BalanceSnapshot is the real balance a user observed on a date.
type BalanceSnapshot struct {
	AccountID string
	Date      civil.Date
	Amount    int64
	UpdatedAt time.Time
	Deleted   bool
}

// BudgetGoal is the needs/wants/savings split effective from a month.
type BudgetGoal struct {
	EffectiveMonth YearMonth
	NeedsPct       int64
	WantsPct       int64
	SavingsPct     int64
	PlannedIncome  *int64
	Deleted        bool
}
