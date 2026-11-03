// Package model holds the GORM entities of the wallet module.
package model

import (
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// Account types (DATA_MODEL.md §1.2 account_type).
const (
	TypeBank    = "bank"
	TypeEWallet = "e_wallet"
	TypeCash    = "cash"
	TypeSavings = "savings"
)

// Account is a [sync] row of the accounts table.
type Account struct {
	syncbase.Columns
	Name           string         `gorm:"type:varchar(50);not null" json:"name"`
	Type           string         `gorm:"type:varchar(16);not null" json:"type"`
	ProviderKey    *string        `gorm:"type:varchar(32)" json:"provider_key"`
	Currency       string         `gorm:"type:char(3);not null" json:"currency"`
	OpeningBalance int64          `gorm:"type:bigint;not null" json:"opening_balance"`
	OpeningDate    civil.Date     `gorm:"type:date;not null" json:"opening_date"`
	IncludeInTotal bool           `gorm:"not null" json:"include_in_total"`
	SortOrder      int            `gorm:"type:integer;not null" json:"sort_order"`
	ArchivedAt     *syncbase.Time `gorm:"type:timestamptz" json:"archived_at"`
}

// TableName returns the table name.
func (Account) TableName() string { return "accounts" }
