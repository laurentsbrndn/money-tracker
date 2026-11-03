package syncbase

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"moneytracker/internal/platform/database"
)

// Row is a model that embeds Columns.
type Row interface {
	Sync() *Columns
}

// Repository implements the persistence every [sync] table shares: ownership-free lookup for
// LWW, whole-row upsert, tombstone, and cursor paging. Modules wrap it and add their own
// queries through DB. Every write stamps server_version and server_updated_at.
type Repository[T any, P interface {
	*T
	Row
}] struct {
	db *database.TxManager
}

// NewRepository builds a repository for model T.
func NewRepository[T any, P interface {
	*T
	Row
}](db *database.TxManager) *Repository[T, P] {
	return &Repository[T, P]{db: db}
}

// DB returns the transaction-aware GORM handle for custom queries.
func (r *Repository[T, P]) DB(ctx context.Context) *gorm.DB {
	return r.db.DB(ctx)
}

// FindAnyUser loads the row by id without a user filter (ownership and LWW checks). It returns
// (nil, nil) when the row does not exist.
func (r *Repository[T, P]) FindAnyUser(ctx context.Context, id uuid.UUID) (P, error) {
	return r.first(r.db.DB(ctx).Where("id = ?", id))
}

// Find loads the user's row, or (nil, nil).
func (r *Repository[T, P]) Find(ctx context.Context, userID, id uuid.UUID) (P, error) {
	return r.first(r.db.DB(ctx).Where("id = ? AND user_id = ?", id, userID))
}

func (r *Repository[T, P]) first(q *gorm.DB) (P, error) {
	row := P(new(T))
	if err := q.Take(row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load sync row: %w", err)
	}
	return row, nil
}

// Save stamps the row and writes it whole, inserting or replacing by id. Call it inside the
// transaction that holds the user's advisory lock.
func (r *Repository[T, P]) Save(ctx context.Context, row P, now time.Time) error {
	db := r.db.DB(ctx)
	if err := row.Sync().Stamp(ctx, db, now); err != nil {
		return err
	}
	err := db.Clauses(clause.OnConflict{Columns: []clause.Column{{Name: "id"}}, UpdateAll: true}).Create(row).Error
	if err != nil {
		return fmt.Errorf("save sync row: %w", err)
	}
	return nil
}

// Tombstone marks the row deleted at `at` (deleted_at and updated_at) and stamps it.
func (r *Repository[T, P]) Tombstone(ctx context.Context, userID, id uuid.UUID, at Time, now time.Time) error {
	db := r.db.DB(ctx)
	var cols Columns
	if err := cols.Stamp(ctx, db, now); err != nil {
		return err
	}
	err := db.Model(new(T)).Where("id = ? AND user_id = ?", id, userID).Updates(map[string]any{
		"deleted_at":        at,
		"updated_at":        at,
		"server_version":    cols.ServerVersion,
		"server_updated_at": cols.ServerUpdatedAt,
	}).Error
	if err != nil {
		return fmt.Errorf("tombstone sync row: %w", err)
	}
	return nil
}

// PullSince returns the user's rows with server_version > since, ascending, at most limit.
func (r *Repository[T, P]) PullSince(ctx context.Context, userID uuid.UUID, since int64, limit int) ([]T, error) {
	var rows []T
	err := r.db.DB(ctx).Where("user_id = ? AND server_version > ?", userID, since).
		Order("server_version").Limit(limit).Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("pull sync rows: %w", err)
	}
	return rows, nil
}

// DeleteByUser permanently removes every row of the user (account purge).
func (r *Repository[T, P]) DeleteByUser(ctx context.Context, userID uuid.UUID) error {
	if err := r.db.DB(ctx).Where("user_id = ?", userID).Delete(new(T)).Error; err != nil {
		return fmt.Errorf("delete user sync rows: %w", err)
	}
	return nil
}
