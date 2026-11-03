// Package dto holds the push payloads of the budget module.
package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// BudgetGoalRow is the `data` of a budget_goals upsert.
type BudgetGoalRow struct {
	ID             uuid.UUID      `json:"id" validate:"required"`
	EffectiveMonth *civil.Date    `json:"effective_month" validate:"required"`
	NeedsPct       *int           `json:"needs_pct" validate:"required,min=0,max=100"`
	WantsPct       *int           `json:"wants_pct" validate:"required,min=0,max=100"`
	SavingsPct     *int           `json:"savings_pct" validate:"required,min=0,max=100"`
	PlannedIncome  *int64         `json:"planned_income"`
	CreatedAt      *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt      *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt      *syncbase.Time `json:"deleted_at"`
}
