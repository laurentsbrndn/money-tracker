// Package ledger owns transactions and recurring rules. Other modules use only this file.
package ledger

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
)

// AggregateQuery selects the reference date and the month for Aggregates.
type AggregateQuery = service.AggregateQuery

// AggregateResult holds the counted flows and the month's category totals.
type AggregateResult = service.AggregateResult

// CategoryTotal is the sum of one category.
type CategoryTotal = service.CategoryTotal

// Timezones tells the IANA timezone of a user. The composition root implements it with
// identity's settings, because ledger may not import identity (docs/ARCHITECTURE.md §3.2).
type Timezones = service.Timezones

// Ledger is the public interface of the module. Besides the report reads, ledger answers "is
// this account / category still used?" through the two checkers below, and pauses recurring
// rules when premium ends.
type Ledger interface {
	// Aggregates reads, for the report, the user's counted transactions up to q.AsOf summed
	// per day/type/accounts/allocation (in the shape of domainrules) plus the month's totals
	// per category (docs/BACKEND.md §6.3).
	Aggregates(ctx context.Context, userID uuid.UUID, q AggregateQuery) (AggregateResult, error)
	// Flows is the first half of Aggregates: only the counted flows up to asOf.
	Flows(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]domainrules.Transaction, error)
	// PauseRules pauses the user's live recurring rules (premium ended, docs/BUSINESS_RULES.md
	// §7). It takes the user lock itself and joins a transaction that already holds it.
	PauseRules(ctx context.Context, userID uuid.UUID) error
	// AccountReferences answers whether live transactions use an account (wallet's callback).
	AccountReferences() wallet.ReferenceChecker
	// CategoryReferences answers whether live transactions use a category (category's callback).
	CategoryReferences() category.ReferenceChecker
}
