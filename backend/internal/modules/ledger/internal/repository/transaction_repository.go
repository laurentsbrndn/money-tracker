// Package repository holds the queries of the ledger module.
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// TransactionRepository stores transactions.
type TransactionRepository struct {
	*syncbase.Repository[model.Transaction, *model.Transaction]
}

// NewTransactionRepository builds the repository.
func NewTransactionRepository(db *database.TxManager) *TransactionRepository {
	return &TransactionRepository{Repository: syncbase.NewRepository[model.Transaction](db)}
}

// UsesAccount reports whether a live transaction has the account as source or destination.
func (r *TransactionRepository) UsesAccount(ctx context.Context, userID, accountID uuid.UUID) (bool, error) {
	var n int64
	err := r.DB(ctx).Model(&model.Transaction{}).
		Where("user_id = ? AND deleted_at IS NULL AND (account_id = ? OR to_account_id = ?)", userID, accountID, accountID).
		Limit(1).Count(&n).Error
	if err != nil {
		return false, fmt.Errorf("check account references: %w", err)
	}
	return n > 0, nil
}

// UsesCategory reports whether a live transaction has the category.
func (r *TransactionRepository) UsesCategory(ctx context.Context, userID, categoryID uuid.UUID) (bool, error) {
	var n int64
	err := r.DB(ctx).Model(&model.Transaction{}).
		Where("user_id = ? AND deleted_at IS NULL AND category_id = ?", userID, categoryID).
		Limit(1).Count(&n).Error
	if err != nil {
		return false, fmt.Errorf("check category references: %w", err)
	}
	return n > 0, nil
}
