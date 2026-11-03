// Package model holds the GORM entity of the budget module.
package model

import (
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// BudgetGoal is a [sync] row of the budget_goals table. Its ID is deterministic: UUIDv5 of
// NS_BUDGET_GOAL and "<user_id>|<YYYY-MM>" (docs/SYNC_PROTOCOL.md §3).
type BudgetGoal struct {
	syncbase.Columns
	EffectiveMonth civil.Date `gorm:"type:date;not null" json:"effective_month"`
	NeedsPct       int16      `gorm:"type:smallint;not null" json:"needs_pct"`
	WantsPct       int16      `gorm:"type:smallint;not null" json:"wants_pct"`
	SavingsPct     int16      `gorm:"type:smallint;not null" json:"savings_pct"`
	PlannedIncome  *int64     `gorm:"type:bigint" json:"planned_income"`
}

// TableName returns the table name.
func (BudgetGoal) TableName() string { return "budget_goals" }
