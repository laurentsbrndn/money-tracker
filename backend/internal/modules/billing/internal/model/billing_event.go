package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

// BillingEvent is a received RevenueCat webhook event; its id is the idempotency key.
type BillingEvent struct {
	ID             string         `gorm:"type:varchar(100);primaryKey"`
	UserID         *uuid.UUID     `gorm:"type:uuid"`
	Type           string         `gorm:"type:varchar(50);not null"`
	EventTimestamp time.Time      `gorm:"type:timestamptz;not null"`
	Payload        datatypes.JSON `gorm:"type:jsonb;not null"`
	ReceivedAt     time.Time      `gorm:"type:timestamptz;not null"`
	ProcessedAt    *time.Time     `gorm:"type:timestamptz"`
	Error          *string        `gorm:"type:text"`
}

// TableName returns the table name.
func (BillingEvent) TableName() string { return "billing_events" }
