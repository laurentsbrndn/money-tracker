// Package budget owns budget goals. Other modules use only this file.
package budget

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
)

// Goals is the public interface of the module.
type Goals interface {
	// CreateDefault creates the 50/30/20 goal for month (new users).
	CreateDefault(ctx context.Context, userID uuid.UUID, month domainrules.YearMonth) error
	// EffectiveFor returns the goal in force for month, or false when there is none.
	EffectiveFor(ctx context.Context, userID uuid.UUID, month domainrules.YearMonth) (domainrules.BudgetGoal, bool, error)
}
