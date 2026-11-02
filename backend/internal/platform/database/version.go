package database

import (
	"context"
	"fmt"

	"gorm.io/gorm"
)

// NextSyncVersion returns the next value of sync_version_seq, shared by all [sync] tables.
func NextSyncVersion(ctx context.Context, tx *gorm.DB) (int64, error) {
	var version int64
	if err := tx.WithContext(ctx).Raw("SELECT nextval('sync_version_seq')").Scan(&version).Error; err != nil {
		return 0, fmt.Errorf("next sync version: %w", err)
	}
	return version, nil
}
