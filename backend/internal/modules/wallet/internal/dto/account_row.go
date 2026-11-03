// Package dto holds the push payloads of the wallet module.
package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// AccountRow is the `data` of an accounts upsert.
type AccountRow struct {
	ID             uuid.UUID      `json:"id" validate:"required"`
	Name           string         `json:"name" validate:"required"`
	Type           string         `json:"type" validate:"required,oneof=bank e_wallet cash savings"`
	ProviderKey    *string        `json:"provider_key" validate:"omitempty,max=32"`
	Currency       string         `json:"currency" validate:"required"`
	OpeningBalance *int64         `json:"opening_balance" validate:"required"`
	OpeningDate    *civil.Date    `json:"opening_date" validate:"required"`
	IncludeInTotal *bool          `json:"include_in_total" validate:"required"`
	SortOrder      *int           `json:"sort_order" validate:"required"`
	ArchivedAt     *syncbase.Time `json:"archived_at"`
	CreatedAt      *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt      *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt      *syncbase.Time `json:"deleted_at"`
}
