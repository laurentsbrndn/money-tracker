// Package model holds the GORM entities of the billing module.
package model

import (
	"time"

	"github.com/google/uuid"
)

// Stores (DATA_MODEL.md §1.2 store) and subscription statuses (subscription_status).
const (
	StoreAppStore  = "app_store"
	StorePlayStore = "play_store"

	StatusActive         = "active"
	StatusInGracePeriod  = "in_grace_period"
	StatusInBillingRetry = "in_billing_retry"
	StatusCancelled      = "cancelled"
	StatusExpired        = "expired"
	StatusRefunded       = "refunded"

	PeriodTrial  = "trial"
	PeriodIntro  = "intro"
	PeriodNormal = "normal"

	EnvSandbox    = "sandbox"
	EnvProduction = "production"
)

// Subscription is a store subscription of a user (DATA_MODEL.md §8).
type Subscription struct {
	ID                    uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID                uuid.UUID `gorm:"type:uuid;not null"`
	Store                 string    `gorm:"type:varchar(16);not null"`
	ProductID             string    `gorm:"type:varchar(100);not null"`
	Status                string    `gorm:"type:varchar(24);not null"`
	PeriodType            string    `gorm:"type:varchar(16);not null"`
	CurrentPeriodStart    time.Time `gorm:"type:timestamptz;not null"`
	CurrentPeriodEnd      time.Time `gorm:"type:timestamptz;not null"`
	WillRenew             bool      `gorm:"not null"`
	OriginalTransactionID string    `gorm:"type:varchar(100);not null"`
	Environment           string    `gorm:"type:varchar(12);not null"`
	CreatedAt             time.Time `gorm:"type:timestamptz;not null"`
	UpdatedAt             time.Time `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (Subscription) TableName() string { return "subscriptions" }
