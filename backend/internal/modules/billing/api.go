// Package billing owns the premium entitlement and the free-plan limits. Other modules use
// only what this file exposes (docs/ARCHITECTURE.md §3).
package billing

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/billing/internal/service"
)

// Entitlement is the premium status of a user (docs/API.md §6).
type Entitlement = service.Entitlement

// Entitlements answers premium questions.
type Entitlements interface {
	// IsPremium reports whether the user has an active premium entitlement.
	IsPremium(ctx context.Context, userID uuid.UUID) (bool, error)
	// Get returns the entitlement shown to the app.
	Get(ctx context.Context, userID uuid.UUID) (Entitlement, error)
}

// Free plan limits (docs/BUSINESS_RULES.md §7).
const (
	MaxFreeAccounts         = service.MaxFreeAccounts
	MaxFreeCustomCategories = service.MaxFreeCustomCategories
	FreeHistoryMonths       = service.FreeHistoryMonths
)

// AccountLimitReached reports whether a user with activeAccounts active accounts may not add
// another one.
func AccountLimitReached(premium bool, activeAccounts int) bool {
	return service.AccountLimitReached(premium, activeAccounts)
}

// CustomCategoryLimitReached reports whether a user with customCategories custom categories
// may not add another one.
func CustomCategoryLimitReached(premium bool, customCategories int) bool {
	return service.CustomCategoryLimitReached(premium, customCategories)
}

// HistoryMonthAllowed reports whether month may be viewed, given the current month.
func HistoryMonthAllowed(premium bool, month, current domainrules.YearMonth) bool {
	return service.HistoryMonthAllowed(premium, month, current)
}

// RecurringAllowed reports whether recurring rules may be created or enabled.
func RecurringAllowed(premium bool) bool {
	return service.RecurringAllowed(premium)
}

// AdvancedReportsAllowed reports whether trend, comparison, unrecorded-difference reports
// and export are available.
func AdvancedReportsAllowed(premium bool) bool {
	return service.AdvancedReportsAllowed(premium)
}
