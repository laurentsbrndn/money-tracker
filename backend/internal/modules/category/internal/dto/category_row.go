// Package dto holds the push payloads of the category module.
package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/syncbase"
)

// CategoryRow is the `data` of a categories upsert. Required non-null fields are pointers
// (or strings) with `required`; nullable fields may be absent.
type CategoryRow struct {
	ID                uuid.UUID      `json:"id" validate:"required"`
	Type              string         `json:"type" validate:"required,oneof=expense income"`
	Name              string         `json:"name" validate:"required"`
	Icon              string         `json:"icon" validate:"required,max=50"`
	Color             string         `json:"color" validate:"required"`
	DefaultAllocation *string        `json:"default_allocation" validate:"omitempty,oneof=needs wants savings"`
	SortOrder         *int           `json:"sort_order" validate:"required"`
	IsDefault         *bool          `json:"is_default" validate:"required"`
	IsHidden          *bool          `json:"is_hidden" validate:"required"`
	ArchivedAt        *syncbase.Time `json:"archived_at"`
	CreatedAt         *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt         *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt         *syncbase.Time `json:"deleted_at"`
}
