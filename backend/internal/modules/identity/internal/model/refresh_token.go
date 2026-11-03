package model

import (
	"time"

	"github.com/google/uuid"
)

// RefreshToken is one link of a rotation chain. Tokens of one login share a FamilyID,
// which is also the session ID (access token claim sid). Only the SHA-256 hash is stored.
// IPAddress is kept for session audit only and never used for security decisions.
type RefreshToken struct {
	ID         uuid.UUID  `gorm:"type:uuid;primaryKey"`
	UserID     uuid.UUID  `gorm:"type:uuid;not null"`
	FamilyID   uuid.UUID  `gorm:"type:uuid;not null"`
	TokenHash  string     `gorm:"type:char(64);not null"`
	DeviceID   string     `gorm:"type:varchar(64);not null"`
	DeviceName *string    `gorm:"type:varchar(100)"`
	IPAddress  *string    `gorm:"type:varchar(45)"`
	ExpiresAt  time.Time  `gorm:"type:timestamptz;not null"`
	RotatedAt  *time.Time `gorm:"type:timestamptz"`
	RevokedAt  *time.Time `gorm:"type:timestamptz"`
	CreatedAt  time.Time  `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (RefreshToken) TableName() string { return "refresh_tokens" }
