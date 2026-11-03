package model

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// BalanceSnapshot is a [sync] row of the balance_snapshots table: the real balance a user saw.
type BalanceSnapshot struct {
	syncbase.Columns
	AccountID    uuid.UUID  `gorm:"type:uuid;not null" json:"account_id"`
	SnapshotDate civil.Date `gorm:"type:date;not null" json:"snapshot_date"`
	Amount       int64      `gorm:"type:bigint;not null" json:"amount"`
	Note         *string    `gorm:"type:varchar(255)" json:"note"`
}

// TableName returns the table name.
func (BalanceSnapshot) TableName() string { return "balance_snapshots" }
