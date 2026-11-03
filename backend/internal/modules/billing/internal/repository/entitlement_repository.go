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

// EntitlementRepository stores entitlements.
type EntitlementRepository struct {
	db *database.TxManager
}

// NewEntitlementRepository builds the repository.
func NewEntitlementRepository(db *database.TxManager) *EntitlementRepository {
	return &EntitlementRepository{db: db}
}

// Get loads the user's entitlement, or (nil, nil).
func (r *EntitlementRepository) Get(ctx context.Context, userID uuid.UUID, key string) (*model.Entitlement, error) {
	var ent model.Entitlement
	err := r.db.DB(ctx).Where("user_id = ? AND entitlement_key = ?", userID, key).Take(&ent).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load entitlement: %w", err)
	}
	return &ent, nil
}

// Save inserts or replaces the entitlement row.
func (r *EntitlementRepository) Save(ctx context.Context, ent *model.Entitlement) error {
	err := r.db.DB(ctx).Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "user_id"}, {Name: "entitlement_key"}},
		UpdateAll: true,
	}).Create(ent).Error
	if err != nil {
		return fmt.Errorf("save entitlement: %w", err)
	}
	return nil
}

// ClearSubscription unlinks every entitlement of other users from a subscription. A transfer
// moves the subscription to a new owner; the old owner's entitlement must not keep pointing at
// it (and would block deleting the new owner's subscription row).
func (r *EntitlementRepository) ClearSubscription(ctx context.Context, subscriptionID, exceptUser uuid.UUID) error {
	err := r.db.DB(ctx).Model(&model.Entitlement{}).
		Where("subscription_id = ? AND user_id <> ?", subscriptionID, exceptUser).
		Update("subscription_id", nil).Error
	if err != nil {
		return fmt.Errorf("unlink entitlements from subscription: %w", err)
	}
	return nil
}
