// Package wallet owns accounts and balance snapshots. Other modules use only this file.
package wallet

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/wallet/internal/service"
	"moneytracker/internal/platform/civil"
)

// Account is the public view of an account.
type Account = service.Account

// ErrNotFound is returned by Accounts.Get for an unknown account.
var ErrNotFound = service.ErrNotFound

// ReferenceChecker reports whether live transactions still use an account. ledger implements
// it; the composition root injects it.
type ReferenceChecker = service.ReferenceChecker

// Accounts is the public interface of the module.
type Accounts interface {
	// Get returns the user's account (deleted ones included, flagged) or ErrNotFound.
	Get(ctx context.Context, userID, id uuid.UUID) (Account, error)
	// List returns the user's live accounts.
	List(ctx context.Context, userID uuid.UUID) ([]Account, error)
	// CreateCash creates the Cash account and its first snapshot (docs/BUSINESS_RULES.md §2.2).
	CreateCash(ctx context.Context, userID uuid.UUID, openingDate civil.Date) error
	// ForRules returns the live accounts (archived included) as inputs for domainrules.
	ForRules(ctx context.Context, userID uuid.UUID) ([]domainrules.Account, error)
	// CountActive counts accounts that are neither deleted nor archived.
	CountActive(ctx context.Context, userID uuid.UUID) (int, error)
}

// Snapshots reads balance snapshots for other modules.
type Snapshots interface {
	// Latest returns each account's newest live snapshot rows dated on or before asOf, as
	// inputs for domainrules (which picks one by date, then updated_at).
	Latest(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]domainrules.BalanceSnapshot, error)
}
