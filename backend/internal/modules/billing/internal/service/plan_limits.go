// Package service holds billing's business logic.
package service

import "moneytracker/internal/domainrules"

// Free plan limits (docs/BUSINESS_RULES.md §7). Premium has no limits.
const (
	// MaxFreeAccounts is the number of active (not deleted, not archived) accounts.
	MaxFreeAccounts = 4
	// MaxFreeCustomCategories is the number of custom (is_default = false, not deleted) categories.
	MaxFreeCustomCategories = 5
	// FreeHistoryMonths is how many months before the current month a free user can still view.
	FreeHistoryMonths = 2
)

// AccountLimitReached reports whether a user with activeAccounts accounts may not add another.
func AccountLimitReached(premium bool, activeAccounts int) bool {
	return !premium && activeAccounts >= MaxFreeAccounts
}

// CustomCategoryLimitReached reports whether a user with customCategories custom categories
// may not add another.
func CustomCategoryLimitReached(premium bool, customCategories int) bool {
	return !premium && customCategories >= MaxFreeCustomCategories
}

// HistoryMonthAllowed reports whether month may be viewed: premium sees every month, free
// sees the current month and the two before it.
func HistoryMonthAllowed(premium bool, month, current domainrules.YearMonth) bool {
	return premium || month.Compare(current.AddMonths(-FreeHistoryMonths)) >= 0
}

// RecurringAllowed reports whether recurring rules may be created or enabled.
func RecurringAllowed(premium bool) bool { return premium }

// AdvancedReportsAllowed reports whether trend, comparison, unrecorded-difference reports and
// export are available.
func AdvancedReportsAllowed(premium bool) bool { return premium }
