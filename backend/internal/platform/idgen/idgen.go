package idgen

import (
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/platform/civil"
)

// Namespaces for deterministic IDs; identical on all platforms (docs/SYNC_PROTOCOL.md §3).
var (
	NSBudgetGoal          = uuid.MustParse("2c985cd5-0cd0-404d-bcea-4cca9c3f7437")
	NSRecurringOccurrence = uuid.MustParse("151a0b48-a293-4aba-95a8-6562233ef7af")
)

// NewV7 returns a new time-ordered UUIDv7.
func NewV7() (uuid.UUID, error) {
	id, err := uuid.NewV7()
	if err != nil {
		return uuid.Nil, fmt.Errorf("generate uuidv7: %w", err)
	}
	return id, nil
}

// V5 returns the UUIDv5 of name in namespace ns.
func V5(ns uuid.UUID, name string) uuid.UUID {
	return uuid.NewSHA1(ns, []byte(name))
}

// BudgetGoalID is UUIDv5(NS_BUDGET_GOAL, "<user_id>|<YYYY-MM>").
func BudgetGoalID(userID uuid.UUID, month string) uuid.UUID {
	return V5(NSBudgetGoal, userID.String()+"|"+month)
}

// RecurringOccurrenceID is UUIDv5(NS_RECURRING_OCCURRENCE, "<rule_id>|<YYYY-MM-DD>").
func RecurringOccurrenceID(ruleID uuid.UUID, date civil.Date) uuid.UUID {
	return V5(NSRecurringOccurrence, ruleID.String()+"|"+date.String())
}
