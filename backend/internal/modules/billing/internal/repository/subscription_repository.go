package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"moneytracker/internal/modules/billing/internal/model"
	"moneytracker/internal/platform/database"
)

// SubscriptionRepository stores subscriptions.
type SubscriptionRepository struct {
	db *database.TxManager
}

// NewSubscriptionRepository builds the repository.
func NewSubscriptionRepository(db *database.TxManager) *SubscriptionRepository {
	return &SubscriptionRepository{db: db}
}

// Get loads a subscription by id, or (nil, nil).
func (r *SubscriptionRepository) Get(ctx context.Context, id uuid.UUID) (*model.Subscription, error) {
	return r.first(r.db.DB(ctx).Where("id = ?", id))
}

// FindByOriginal loads the subscription of a store transaction chain, whoever owns it.
func (r *SubscriptionRepository) FindByOriginal(ctx context.Context, store, originalTransactionID string) (*model.Subscription, error) {
	return r.first(r.db.DB(ctx).Where("store = ? AND original_transaction_id = ?", store, originalTransactionID))
}

// FindLatest loads the user's most recently updated subscription of a store product.
func (r *SubscriptionRepository) FindLatest(ctx context.Context, userID uuid.UUID, store, productID string) (*model.Subscription, error) {
	return r.first(r.db.DB(ctx).Where("user_id = ? AND store = ? AND product_id = ?", userID, store, productID).Order("updated_at DESC"))
}

func (r *SubscriptionRepository) first(q *gorm.DB) (*model.Subscription, error) {
	var sub model.Subscription
	if err := q.Take(&sub).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load subscription: %w", err)
	}
	return &sub, nil
}

// Save inserts the subscription or, when (store, original_transaction_id) exists, updates it.
// The id and created_at of the existing row are kept; the owner may change (a transfer).
func (r *SubscriptionRepository) Save(ctx context.Context, sub *model.Subscription) error {
	err := r.db.DB(ctx).Clauses(clause.OnConflict{
		Columns: []clause.Column{{Name: "store"}, {Name: "original_transaction_id"}},
		DoUpdates: clause.AssignmentColumns([]string{
			"user_id", "product_id", "status", "period_type", "current_period_start",
			"current_period_end", "will_renew", "environment", "updated_at",
		}),
	}).Create(sub).Error
	if err != nil {
		return fmt.Errorf("save subscription: %w", err)
	}
	return nil
}
