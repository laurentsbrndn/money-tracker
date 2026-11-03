// Package repository holds the queries of the wallet module.
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// AccountRepository stores accounts.
type AccountRepository struct {
	*syncbase.Repository[model.Account, *model.Account]
}

// NewAccountRepository builds the repository.
func NewAccountRepository(db *database.TxManager) *AccountRepository {
	return &AccountRepository{Repository: syncbase.NewRepository[model.Account](db)}
}

// CountActive counts the user's accounts that are neither deleted nor archived, not counting
// excludeID.
func (r *AccountRepository) CountActive(ctx context.Context, userID, excludeID uuid.UUID) (int, error) {
	var n int64
	err := r.DB(ctx).Model(&model.Account{}).
		Where("user_id = ? AND deleted_at IS NULL AND archived_at IS NULL AND id <> ?", userID, excludeID).
		Count(&n).Error
	if err != nil {
		return 0, fmt.Errorf("count active accounts: %w", err)
	}
	return int(n), nil
}

// List returns the user's live accounts ordered for display.
func (r *AccountRepository) List(ctx context.Context, userID uuid.UUID) ([]model.Account, error) {
	var rows []model.Account
	err := r.DB(ctx).Where("user_id = ? AND deleted_at IS NULL", userID).Order("sort_order, created_at").Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("list accounts: %w", err)
	}
	return rows, nil
}
