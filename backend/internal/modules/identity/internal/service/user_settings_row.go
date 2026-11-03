package service

import (
	"github.com/google/uuid"

	"moneytracker/internal/platform/syncbase"
)

// UserSettingsRow is the `data` of a user_settings upsert. It lives next to the service
// (not in dto) because dto already imports service.
type UserSettingsRow struct {
	ID                       uuid.UUID      `json:"id" validate:"required"`
	Timezone                 string         `json:"timezone" validate:"required"`
	Currency                 string         `json:"currency" validate:"required"`
	WeekStart                *int           `json:"week_start" validate:"required"`
	Theme                    string         `json:"theme" validate:"required,oneof=system light dark"`
	DailyReminderTime        *string        `json:"daily_reminder_time"`
	ReconcileReminderEnabled *bool          `json:"reconcile_reminder_enabled" validate:"required"`
	BudgetAlertEnabled       *bool          `json:"budget_alert_enabled" validate:"required"`
	HideAmounts              *bool          `json:"hide_amounts" validate:"required"`
	CreatedAt                *syncbase.Time `json:"created_at" validate:"required"`
	UpdatedAt                *syncbase.Time `json:"updated_at" validate:"required"`
	DeletedAt                *syncbase.Time `json:"deleted_at"`
}
