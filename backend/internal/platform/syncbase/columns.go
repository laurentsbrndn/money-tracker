package syncbase

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"moneytracker/internal/platform/database"
)

// Columns are the mandatory columns of every [sync] table (docs/DATA_MODEL.md §1.1).
// Embed it in each sync entity model.
//
// created_at and updated_at come from the client, so GORM's automatic timestamps are off.
// DeletedAt is a plain tombstone column, not gorm.DeletedAt: tombstones must stay visible to pull.
// Timestamps use Time so that they always serialize with exactly three fractional digits.
// The JSON tags match the wire format: user_id, server_version and server_updated_at are never sent.
type Columns struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	UserID          uuid.UUID `gorm:"type:uuid;not null" json:"-"`
	CreatedAt       Time      `gorm:"type:timestamptz;not null;autoCreateTime:false" json:"created_at"`
	UpdatedAt       Time      `gorm:"type:timestamptz;not null;autoUpdateTime:false" json:"updated_at"`
	DeletedAt       *Time     `gorm:"type:timestamptz" json:"deleted_at"`
	ServerVersion   int64     `gorm:"not null" json:"-"`
	ServerUpdatedAt Time      `gorm:"type:timestamptz;not null;autoUpdateTime:false" json:"-"`
}

// Sync returns the columns themselves; models embed Columns, so *Model satisfies Row.
func (c *Columns) Sync() *Columns {
	return c
}

// Stamp sets ServerVersion from sync_version_seq and ServerUpdatedAt to now.
// Call it on every write, inside the transaction that holds the user's advisory lock.
func (c *Columns) Stamp(ctx context.Context, tx *gorm.DB, now time.Time) error {
	version, err := database.NextSyncVersion(ctx, tx)
	if err != nil {
		return fmt.Errorf("stamp sync columns: %w", err)
	}
	c.ServerVersion = version
	c.ServerUpdatedAt = NewTime(now)
	return nil
}

// StampAll stamps several rows, possibly of different tables, with one version query. The rows
// get ascending versions in the order given, and all share the same ServerUpdatedAt.
func StampAll(ctx context.Context, tx *gorm.DB, now time.Time, cols ...*Columns) error {
	versions, err := database.NextSyncVersions(ctx, tx, len(cols))
	if err != nil {
		return fmt.Errorf("stamp sync columns: %w", err)
	}
	for i, c := range cols {
		c.ServerVersion = versions[i]
		c.ServerUpdatedAt = NewTime(now)
	}
	return nil
}
