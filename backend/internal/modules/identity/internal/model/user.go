package model

import (
	"time"

	"github.com/google/uuid"
)

// User statuses (DATA_MODEL.md §1.2 user_status).
const (
	UserStatusActive          = "active"
	UserStatusPendingDeletion = "pending_deletion"
)

// User is the account row. Email is always lowercase; it is nil for Apple users who hide it.
type User struct {
	ID                  uuid.UUID  `gorm:"type:uuid;primaryKey"`
	Email               *string    `gorm:"type:varchar(254)"`
	EmailVerifiedAt     *time.Time `gorm:"type:timestamptz"`
	PasswordHash        *string    `gorm:"type:text"`
	Name                string     `gorm:"type:varchar(100);not null"`
	Status              string     `gorm:"type:varchar(16);not null"`
	FailedLoginCount    int        `gorm:"not null"`
	LockedUntil         *time.Time `gorm:"type:timestamptz"`
	DeletionRequestedAt *time.Time `gorm:"type:timestamptz"`
	CreatedAt           time.Time  `gorm:"type:timestamptz;not null"`
	UpdatedAt           time.Time  `gorm:"type:timestamptz;not null"`
}

// TableName returns the table name.
func (User) TableName() string { return "users" }
