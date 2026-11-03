// Package model holds the GORM entity of the category module.
package model

import "moneytracker/internal/platform/syncbase"

// Category types (DATA_MODEL.md §1.2 category_type).
const (
	TypeExpense = "expense"
	TypeIncome  = "income"
)

// Category is a [sync] row of the categories table.
type Category struct {
	syncbase.Columns
	Type              string         `gorm:"type:varchar(8);not null" json:"type"`
	Name              string         `gorm:"type:varchar(50);not null" json:"name"`
	Icon              string         `gorm:"type:varchar(50);not null" json:"icon"`
	Color             string         `gorm:"type:varchar(7);not null" json:"color"`
	DefaultAllocation *string        `gorm:"type:varchar(8)" json:"default_allocation"`
	SortOrder         int            `gorm:"type:integer;not null" json:"sort_order"`
	IsDefault         bool           `gorm:"not null" json:"is_default"`
	IsHidden          bool           `gorm:"not null" json:"is_hidden"`
	ArchivedAt        *syncbase.Time `gorm:"type:timestamptz" json:"archived_at"`
}

// TableName returns the table name.
func (Category) TableName() string { return "categories" }
