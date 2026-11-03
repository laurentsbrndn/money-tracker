// Package repository holds the queries of the sync module.
package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"moneytracker/internal/modules/sync/internal/model"
	"moneytracker/internal/platform/database"
)

// IdempotencyKeyRepository reads and writes the sync_idempotency_keys table.
type IdempotencyKeyRepository struct {
	db *database.TxManager
}

// NewIdempotencyKeyRepository builds the repository.
func NewIdempotencyKeyRepository(db *database.TxManager) *IdempotencyKeyRepository {
	return &IdempotencyKeyRepository{db: db}
}

// Find returns the stored key of (user, key), or (nil, nil).
func (r *IdempotencyKeyRepository) Find(ctx context.Context, userID uuid.UUID, key string) (*model.IdempotencyKey, error) {
	var row model.IdempotencyKey
	err := r.db.DB(ctx).Where("user_id = ? AND idempotency_key = ?", userID, key).Take(&row).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load idempotency key: %w", err)
	}
	return &row, nil
}

// Create stores a key with its response.
func (r *IdempotencyKeyRepository) Create(ctx context.Context, row *model.IdempotencyKey) error {
	if err := r.db.DB(ctx).Create(row).Error; err != nil {
		return fmt.Errorf("create idempotency key: %w", err)
	}
	return nil
}

// DeleteByUser removes every key of the user (account purge).
func (r *IdempotencyKeyRepository) DeleteByUser(ctx context.Context, userID uuid.UUID) error {
	if err := r.db.DB(ctx).Where("user_id = ?", userID).Delete(&model.IdempotencyKey{}).Error; err != nil {
		return fmt.Errorf("delete idempotency keys: %w", err)
	}
	return nil
}

// DeleteCreatedBefore removes keys created before cutoff and returns how many.
func (r *IdempotencyKeyRepository) DeleteCreatedBefore(ctx context.Context, cutoff time.Time) (int64, error) {
	res := r.db.DB(ctx).Where("created_at < ?", cutoff).Delete(&model.IdempotencyKey{})
	if res.Error != nil {
		return 0, fmt.Errorf("delete old idempotency keys: %w", res.Error)
	}
	return res.RowsAffected, nil
}
