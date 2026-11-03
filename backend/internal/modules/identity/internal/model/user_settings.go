package model

import "moneytracker/internal/platform/syncbase"

// UserSettings is the [sync] settings row of a user; its ID equals the user ID.
type UserSettings struct {
	syncbase.Columns
	Timezone                 string  `gorm:"type:varchar(64);not null" json:"timezone"`
	Currency                 string  `gorm:"type:char(3);not null" json:"currency"`
	WeekStart                int16   `gorm:"type:smallint;not null" json:"week_start"`
	Theme                    string  `gorm:"type:varchar(8);not null" json:"theme"`
	DailyReminderTime        *string `gorm:"type:varchar(5)" json:"daily_reminder_time"`
	ReconcileReminderEnabled bool    `gorm:"not null" json:"reconcile_reminder_enabled"`
	BudgetAlertEnabled       bool    `gorm:"not null" json:"budget_alert_enabled"`
	HideAmounts              bool    `gorm:"not null" json:"hide_amounts"`
}

// TableName returns the table name.
func (UserSettings) TableName() string { return "user_settings" }
