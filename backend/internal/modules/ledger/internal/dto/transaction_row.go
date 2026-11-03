// Package dto holds the push payloads of the ledger module.
package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// TransactionRow is the `data` of a transactions upsert.
type TransactionRow struct {
	ID                  uuid.UUID      `json:"id" validate:"required"`
	Type                string         `json:"type" validate:"required,oneof=income expense transfer adjustment"`
	Status              string         `json:"status" validate:"required,oneof=posted pending_confirmation"`
	TransactionDate     *civil.Date    `json:"transaction_date" validate:"required"`
	Amount              *int64         `json:"amount" validate:"required"`
	Currency            string         `json:"currency" validate:"required"`
	AccountID           uuid.UUID      `json:"account_id" validate:"required"`
	ToAccountID         *uuid.UUID     `json:"to_account_id"`
	CategoryID          *uuid.UUID     `json:"category_id"`
	Allocation          *string        `json:"allocation" validate:"omitempty,oneof=needs wants savings"`
	Source              *string        `json:"source"`
	Note                *string        `json:"note"`
	LinkedTransactionID *uuid.UUID     `json:"linked_transaction_id"`
	RecurringRuleID     *uuid.UUID     `json:"recurring_rule_id"`
	CreatedAt           *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt           *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt           *syncbase.Time `json:"deleted_at"`
}
