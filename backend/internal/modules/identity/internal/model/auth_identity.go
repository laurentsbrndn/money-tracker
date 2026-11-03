package model

import (
	"time"

	"github.com/google/uuid"
)

// Auth providers (DATA_MODEL.md §1.2 auth_provider).
const (
	ProviderApple  = "apple"
	ProviderGoogle = "google"
)

// AuthIdentity links a user to an Apple or Google account.
type AuthIdentity struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey"`
	UserID          uuid.UUID `gorm:"type:uuid;not null"`
	Provider        string    `gorm:"type:varchar(16);not null"`
	ProviderSubject string    `gorm:"type:varchar(255);not null"`
	Email           *string   `gorm:"type:varchar(254)"`
	CreatedAt       time.Time `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (AuthIdentity) TableName() string { return "auth_identities" }
