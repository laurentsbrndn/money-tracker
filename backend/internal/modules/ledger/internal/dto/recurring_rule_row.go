package dto

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// RecurringRuleRow is the `data` of a recurring_rules upsert.
type RecurringRuleRow struct {
	ID                uuid.UUID      `json:"id" validate:"required"`
	Type              string         `json:"type" validate:"required,oneof=income expense transfer"`
	Amount            *int64         `json:"amount" validate:"required"`
	AccountID         uuid.UUID      `json:"account_id" validate:"required"`
	ToAccountID       *uuid.UUID     `json:"to_account_id"`
	CategoryID        *uuid.UUID     `json:"category_id"`
	Allocation        *string        `json:"allocation" validate:"omitempty,oneof=needs wants savings"`
	Source            *string        `json:"source"`
	Note              *string        `json:"note"`
	Frequency         string         `json:"frequency" validate:"required,oneof=daily weekly monthly yearly"`
	IntervalCount     *int16         `json:"interval_count" validate:"required,min=1,max=366"`
	DayOfWeek         *int16         `json:"day_of_week"`
	DayOfMonth        *int16         `json:"day_of_month"`
	MonthOfYear       *int16         `json:"month_of_year"`
	StartDate         *civil.Date    `json:"start_date" validate:"required"`
	EndDate           *civil.Date    `json:"end_date"`
	Mode              string         `json:"mode" validate:"required,oneof=auto confirm"`
	IsPaused          *bool          `json:"is_paused" validate:"required"`
	LastGeneratedDate *civil.Date    `json:"last_generated_date"`
	CreatedAt         *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt         *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt         *syncbase.Time `json:"deleted_at"`
}
