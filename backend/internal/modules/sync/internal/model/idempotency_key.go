// Package model holds the GORM entity of the sync module.
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
)

// IdempotencyKey stores the response of a push so that a retry with the same key returns it
// again instead of applying the changes twice (docs/SYNC_PROTOCOL.md §8.2). The maintenance
// job removes keys older than 24 hours.
type IdempotencyKey struct {
	UserID         uuid.UUID      `gorm:"type:uuid;primaryKey"`
	IdempotencyKey string         `gorm:"type:varchar(64);primaryKey"`
	Response       datatypes.JSON `gorm:"type:jsonb;not null"`
	CreatedAt      time.Time      `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (IdempotencyKey) TableName() string { return "sync_idempotency_keys" }
