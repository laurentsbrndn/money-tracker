// Package wallet owns accounts and balance snapshots. Other modules use only this file.
package wallet

import (
	"context"

	"github.com/google/uuid"

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
	// CountActive counts accounts that are neither deleted nor archived.
	CountActive(ctx context.Context, userID uuid.UUID) (int, error)
}
