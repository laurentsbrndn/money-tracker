package database

import (
	"context"
	"fmt"
	"slices"

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

// NextSyncVersions returns n fresh values of sync_version_seq in ascending order, drawn with a
// single query. Callers hand them out in row order, so the first row written gets the lowest
// version, exactly as n calls to NextSyncVersion would. n <= 0 returns nil.
func NextSyncVersions(ctx context.Context, tx *gorm.DB, n int) ([]int64, error) {
	if n <= 0 {
		return nil, nil
	}
	versions := make([]int64, 0, n)
	err := tx.WithContext(ctx).Raw("SELECT nextval('sync_version_seq') FROM generate_series(1, ?)", n).
		Scan(&versions).Error
	if err != nil {
		return nil, fmt.Errorf("next sync versions: %w", err)
	}
	if len(versions) != n {
		return nil, fmt.Errorf("next sync versions: got %d values, want %d", len(versions), n)
	}
	// The query returns the values in evaluation order; sort so that handing them out in row
	// order is always ascending.
	slices.Sort(versions)
	return versions, nil
}
