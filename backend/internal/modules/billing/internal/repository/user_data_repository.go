// Package repository holds the queries of the billing module.
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing/internal/model"
	"moneytracker/internal/platform/database"
)

// UserDataRepository removes a user's billing rows.
type UserDataRepository struct {
	db *database.TxManager
}

// NewUserDataRepository builds the repository.
func NewUserDataRepository(db *database.TxManager) *UserDataRepository {
	return &UserDataRepository{db: db}
}

// DeleteByUser deletes the user's entitlements, then subscriptions (entitlements.subscription_id
// references subscriptions), then billing events. Rows that do not exist are not an error.
func (r *UserDataRepository) DeleteByUser(ctx context.Context, userID uuid.UUID) error {
	db := r.db.DB(ctx)
	if err := db.Where("user_id = ?", userID).Delete(&model.Entitlement{}).Error; err != nil {
		return fmt.Errorf("delete user entitlements: %w", err)
	}
	if err := db.Where("user_id = ?", userID).Delete(&model.Subscription{}).Error; err != nil {
		return fmt.Errorf("delete user subscriptions: %w", err)
	}
	if err := db.Where("user_id = ?", userID).Delete(&model.BillingEvent{}).Error; err != nil {
		return fmt.Errorf("delete user billing events: %w", err)
	}
	return nil
}
