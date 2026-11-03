// Package repository holds the queries of the category module.
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// CategoryRepository stores categories.
type CategoryRepository struct {
	*syncbase.Repository[model.Category, *model.Category]
}

// NewCategoryRepository builds the repository.
func NewCategoryRepository(db *database.TxManager) *CategoryRepository {
	return &CategoryRepository{Repository: syncbase.NewRepository[model.Category](db)}
}

// NameTaken reports whether a live category of the same type already uses the name,
// ignoring case. excludeID is the row being written.
func (r *CategoryRepository) NameTaken(ctx context.Context, userID uuid.UUID, categoryType, name string, excludeID uuid.UUID) (bool, error) {
	var n int64
	err := r.DB(ctx).Model(&model.Category{}).
		Where("user_id = ? AND type = ? AND LOWER(name) = LOWER(?) AND deleted_at IS NULL AND id <> ?",
			userID, categoryType, name, excludeID).
		Count(&n).Error
	if err != nil {
		return false, fmt.Errorf("check category name: %w", err)
	}
	return n > 0, nil
}

// CountCustom counts the user's custom (is_default = false) live categories, not counting excludeID.
func (r *CategoryRepository) CountCustom(ctx context.Context, userID, excludeID uuid.UUID) (int, error) {
	var n int64
	err := r.DB(ctx).Model(&model.Category{}).
		Where("user_id = ? AND is_default = ? AND deleted_at IS NULL AND id <> ?", userID, false, excludeID).
		Count(&n).Error
	if err != nil {
		return 0, fmt.Errorf("count custom categories: %w", err)
	}
	return int(n), nil
}
