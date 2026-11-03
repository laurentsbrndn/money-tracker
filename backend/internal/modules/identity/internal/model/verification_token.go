package model

import (
	"time"

	"github.com/google/uuid"
)

// Verification token purposes (DATA_MODEL.md §1.2 token_purpose).
const (
	PurposeEmailVerification = "email_verification"
	PurposePasswordReset     = "password_reset"
)

// VerificationToken is a 6-digit code (stored as an HMAC) for email verification or password reset.
type VerificationToken struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey"`
	UserID    uuid.UUID  `gorm:"type:uuid;not null"`
	Purpose   string     `gorm:"type:varchar(32);not null"`
	CodeHash  string     `gorm:"type:char(64);not null"`
	Attempts  int16      `gorm:"type:smallint;not null"`
	ExpiresAt time.Time  `gorm:"type:timestamptz;not null"`
	UsedAt    *time.Time `gorm:"type:timestamptz"`
	CreatedAt time.Time  `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (VerificationToken) TableName() string { return "verification_tokens" }
