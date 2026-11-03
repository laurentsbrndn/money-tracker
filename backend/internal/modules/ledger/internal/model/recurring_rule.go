package model

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// Recurring frequencies and modes (DATA_MODEL.md §1.2).
const (
	FrequencyDaily   = "daily"
	FrequencyWeekly  = "weekly"
	FrequencyMonthly = "monthly"
	FrequencyYearly  = "yearly"

	ModeAuto    = "auto"
	ModeConfirm = "confirm"
)

// RecurringRule is a [sync] row of recurring_rules: a transaction template and its schedule.
// DayOfWeek is ISO (Monday = 1 ... Sunday = 7).
type RecurringRule struct {
	syncbase.Columns
	Type              string      `gorm:"type:varchar(16);not null" json:"type"`
	Amount            int64       `gorm:"type:bigint;not null" json:"amount"`
	AccountID         uuid.UUID   `gorm:"type:uuid;not null" json:"account_id"`
	ToAccountID       *uuid.UUID  `gorm:"type:uuid" json:"to_account_id"`
	CategoryID        *uuid.UUID  `gorm:"type:uuid" json:"category_id"`
	Allocation        *string     `gorm:"type:varchar(8)" json:"allocation"`
	Source            *string     `gorm:"type:varchar(100)" json:"source"`
	Note              *string     `gorm:"type:varchar(255)" json:"note"`
	Frequency         string      `gorm:"type:varchar(8);not null" json:"frequency"`
	IntervalCount     int16       `gorm:"type:smallint;not null;default:1" json:"interval_count"`
	DayOfWeek         *int16      `gorm:"type:smallint" json:"day_of_week"`
	DayOfMonth        *int16      `gorm:"type:smallint" json:"day_of_month"`
	MonthOfYear       *int16      `gorm:"type:smallint" json:"month_of_year"`
	StartDate         civil.Date  `gorm:"type:date;not null" json:"start_date"`
	EndDate           *civil.Date `gorm:"type:date" json:"end_date"`
	Mode              string      `gorm:"type:varchar(8);not null" json:"mode"`
	IsPaused          bool        `gorm:"not null" json:"is_paused"`
	LastGeneratedDate *civil.Date `gorm:"type:date" json:"last_generated_date"`
}

// TableName returns the table name.
func (RecurringRule) TableName() string { return "recurring_rules" }
