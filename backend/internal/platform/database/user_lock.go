package database

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// LockUser takes a transaction-level advisory lock for userID (docs/SYNC_PROTOCOL.md §10).
// tx must be an open transaction; the lock is released automatically at commit or rollback.
// Every write to a user's [sync] tables must hold this lock.
func LockUser(ctx context.Context, tx *gorm.DB, userID uuid.UUID) error {
	err := tx.WithContext(ctx).Exec("SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", userID.String()).Error
	if err != nil {
		return fmt.Errorf("lock user %s: %w", userID, err)
	}
	return nil
}
