package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"moneytracker/internal/modules/billing/internal/model"
	"moneytracker/internal/platform/database"
)

// BillingEventRepository stores received webhook events.
type BillingEventRepository struct {
	db *database.TxManager
}

// NewBillingEventRepository builds the repository.
func NewBillingEventRepository(db *database.TxManager) *BillingEventRepository {
	return &BillingEventRepository{db: db}
}

// Insert stores the event; it reports false, writing nothing, when the id already exists.
func (r *BillingEventRepository) Insert(ctx context.Context, ev *model.BillingEvent) (bool, error) {
	res := r.db.DB(ctx).Clauses(clause.OnConflict{DoNothing: true}).Create(ev)
	if res.Error != nil {
		return false, fmt.Errorf("insert billing event: %w", res.Error)
	}
	return res.RowsAffected > 0, nil
}

// Get loads an event, or (nil, nil).
func (r *BillingEventRepository) Get(ctx context.Context, id string) (*model.BillingEvent, error) {
	var ev model.BillingEvent
	if err := r.db.DB(ctx).Where("id = ?", id).Take(&ev).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load billing event: %w", err)
	}
	return &ev, nil
}

// MarkProcessed records that the event was handled; it clears an earlier error.
func (r *BillingEventRepository) MarkProcessed(ctx context.Context, id string, at time.Time) error {
	err := r.db.DB(ctx).Model(&model.BillingEvent{}).Where("id = ?", id).
		Updates(map[string]any{"processed_at": at, "error": nil}).Error
	if err != nil {
		return fmt.Errorf("mark billing event processed: %w", err)
	}
	return nil
}

// MarkFailed records why the event could not be handled.
func (r *BillingEventRepository) MarkFailed(ctx context.Context, id, message string) error {
	err := r.db.DB(ctx).Model(&model.BillingEvent{}).Where("id = ?", id).Update("error", message).Error
	if err != nil {
		return fmt.Errorf("mark billing event failed: %w", err)
	}
	return nil
}

// SetUser records the user the event belongs to.
func (r *BillingEventRepository) SetUser(ctx context.Context, id string, userID uuid.UUID) error {
	err := r.db.DB(ctx).Model(&model.BillingEvent{}).Where("id = ?", id).Update("user_id", userID).Error
	if err != nil {
		return fmt.Errorf("set billing event user: %w", err)
	}
	return nil
}

// NewerProcessedExists reports whether an event of one of types, newer than ts, was already
// handled for the user (another event than excludeID). It tells a late event from a current one.
func (r *BillingEventRepository) NewerProcessedExists(ctx context.Context, userID uuid.UUID, ts time.Time, excludeID string, types []string) (bool, error) {
	var n int64
	err := r.db.DB(ctx).Model(&model.BillingEvent{}).
		Where("user_id = ? AND processed_at IS NOT NULL AND event_timestamp > ? AND id <> ? AND type IN ?", userID, ts, excludeID, types).
		Limit(1).Count(&n).Error
	if err != nil {
		return false, fmt.Errorf("check newer billing events: %w", err)
	}
	return n > 0, nil
}
