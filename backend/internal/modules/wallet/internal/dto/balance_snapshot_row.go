package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// BalanceSnapshotRow is the `data` of a balance_snapshots upsert.
type BalanceSnapshotRow struct {
	ID           uuid.UUID      `json:"id" validate:"required"`
	AccountID    uuid.UUID      `json:"account_id" validate:"required"`
	SnapshotDate *civil.Date    `json:"snapshot_date" validate:"required"`
	Amount       *int64         `json:"amount" validate:"required"`
	Note         *string        `json:"note"`
	CreatedAt    *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt    *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt    *syncbase.Time `json:"deleted_at"`
}
