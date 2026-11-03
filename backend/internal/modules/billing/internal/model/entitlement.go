package model

import (
	"time"

	"github.com/google/uuid"
)

// EntitlementPremium is the only entitlement key (DATA_MODEL.md §8).
const EntitlementPremium = "premium"

// Entitlement says whether a user has an entitlement. ExpiresAt is when access ends (the grace
// period end while in grace); nil means it does not expire.
type Entitlement struct {
	UserID         uuid.UUID  `gorm:"type:uuid;primaryKey"`
	EntitlementKey string     `gorm:"type:varchar(32);primaryKey"`
	IsActive       bool       `gorm:"not null"`
	ExpiresAt      *time.Time `gorm:"type:timestamptz"`
	SubscriptionID *uuid.UUID `gorm:"type:uuid"`
	UpdatedAt      time.Time  `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (Entitlement) TableName() string { return "entitlements" }
