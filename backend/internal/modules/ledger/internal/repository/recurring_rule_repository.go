package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// RecurringRuleRepository stores recurring rules.
type RecurringRuleRepository struct {
	*syncbase.Repository[model.RecurringRule, *model.RecurringRule]
}

// NewRecurringRuleRepository builds the repository.
func NewRecurringRuleRepository(db *database.TxManager) *RecurringRuleRepository {
	return &RecurringRuleRepository{Repository: syncbase.NewRepository[model.RecurringRule](db)}
}

// ActiveSchedules loads the schedule fields of every live, unpaused rule of every user. The
// daily job uses them to find who may be due without opening a transaction per user.
func (r *RecurringRuleRepository) ActiveSchedules(ctx context.Context) ([]model.RecurringRule, error) {
	var rules []model.RecurringRule
	err := r.DB(ctx).
		Select("id", "user_id", "frequency", "interval_count", "day_of_week", "day_of_month", "month_of_year", "start_date", "end_date", "last_generated_date").
		Where("deleted_at IS NULL AND is_paused = ?", false).
		Order("user_id, id").Find(&rules).Error
	if err != nil {
		return nil, fmt.Errorf("list active recurring schedules: %w", err)
	}
	return rules, nil
}

// ListActive loads the user's live, unpaused rules.
func (r *RecurringRuleRepository) ListActive(ctx context.Context, userID uuid.UUID) ([]model.RecurringRule, error) {
	var rules []model.RecurringRule
	err := r.DB(ctx).Where("user_id = ? AND deleted_at IS NULL AND is_paused = ?", userID, false).
		Order("id").Find(&rules).Error
	if err != nil {
		return nil, fmt.Errorf("list recurring rules: %w", err)
	}
	return rules, nil
}

// PauseActive pauses every live, unpaused rule of the user and returns how many it paused.
// Each rule is stamped (new server_version), so the pause reaches every device by pull. Call it
// under the user's lock.
func (r *RecurringRuleRepository) PauseActive(ctx context.Context, userID uuid.UUID, now time.Time) (int, error) {
	rules, err := r.ListActive(ctx, userID)
	if err != nil || len(rules) == 0 {
		return 0, err
	}
	rows := make([]*model.RecurringRule, len(rules))
	for i := range rules {
		rules[i].IsPaused = true
		rules[i].UpdatedAt = syncbase.NewTime(now)
		rows[i] = &rules[i]
	}
	if err := r.SaveMany(ctx, rows, now); err != nil {
		return 0, err
	}
	return len(rows), nil
}
