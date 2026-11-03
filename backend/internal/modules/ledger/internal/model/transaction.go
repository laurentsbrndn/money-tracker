// Package model holds the GORM entities of the ledger module.
package model

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// Transaction types (DATA_MODEL.md §1.2 transaction_type) and statuses.
const (
	TypeIncome     = "income"
	TypeExpense    = "expense"
	TypeTransfer   = "transfer"
	TypeAdjustment = "adjustment"

	StatusPosted              = "posted"
	StatusPendingConfirmation = "pending_confirmation"
)

// Transaction is a [sync] row of the transactions table. Amount is signed for adjustments.
type Transaction struct {
	syncbase.Columns
	Type                string     `gorm:"type:varchar(16);not null" json:"type"`
	Status              string     `gorm:"type:varchar(24);not null" json:"status"`
	TransactionDate     civil.Date `gorm:"type:date;not null" json:"transaction_date"`
	Amount              int64      `gorm:"type:bigint;not null" json:"amount"`
	Currency            string     `gorm:"type:char(3);not null" json:"currency"`
	AccountID           uuid.UUID  `gorm:"type:uuid;not null" json:"account_id"`
	ToAccountID         *uuid.UUID `gorm:"type:uuid" json:"to_account_id"`
	CategoryID          *uuid.UUID `gorm:"type:uuid" json:"category_id"`
	Allocation          *string    `gorm:"type:varchar(8)" json:"allocation"`
	Source              *string    `gorm:"type:varchar(100)" json:"source"`
	Note                *string    `gorm:"type:varchar(255)" json:"note"`
	LinkedTransactionID *uuid.UUID `gorm:"type:uuid" json:"linked_transaction_id"`
	RecurringRuleID     *uuid.UUID `gorm:"type:uuid" json:"recurring_rule_id"`
}

// TableName returns the table name.
func (Transaction) TableName() string { return "transactions" }
