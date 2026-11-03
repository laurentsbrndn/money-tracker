// Package repository holds the queries of the budget module.
package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"moneytracker/internal/modules/budget/internal/model"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// BudgetGoalRepository stores budget goals.
type BudgetGoalRepository struct {
	*syncbase.Repository[model.BudgetGoal, *model.BudgetGoal]
}

// NewBudgetGoalRepository builds the repository.
func NewBudgetGoalRepository(db *database.TxManager) *BudgetGoalRepository {
	return &BudgetGoalRepository{Repository: syncbase.NewRepository[model.BudgetGoal](db)}
}

// EffectiveFor returns the live goal with the latest effective month not after month, or
// (nil, nil).
func (r *BudgetGoalRepository) EffectiveFor(ctx context.Context, userID uuid.UUID, month civil.Date) (*model.BudgetGoal, error) {
	var goal model.BudgetGoal
	err := r.DB(ctx).
		Where("user_id = ? AND deleted_at IS NULL AND effective_month <= ?", userID, month).
		Order("effective_month DESC").Limit(1).Take(&goal).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, fmt.Errorf("load effective goal: %w", err)
	}
	return &goal, nil
}
