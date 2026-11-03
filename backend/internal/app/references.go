package app

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/wallet"
)

var errReferencesNotBound = errors.New("reference checker not bound")

// lateReferences breaks a construction cycle: wallet and category need a ReferenceChecker when
// they are built, but the checker is implemented by ledger, which needs wallet and category.
// Build creates this value first, hands its two checkers to wallet and category, builds ledger,
// and calls bind before the server accepts any connection. Until then (never in practice) the
// checkers fail loudly instead of answering "not referenced".
type lateReferences struct {
	accounts   wallet.ReferenceChecker
	categories category.ReferenceChecker
}

func (l *lateReferences) bind(accounts wallet.ReferenceChecker, categories category.ReferenceChecker) {
	l.accounts = accounts
	l.categories = categories
}

// accountChecker returns the checker handed to wallet.
func (l *lateReferences) accountChecker() wallet.ReferenceChecker {
	return lateAccountChecker{l}
}

// categoryChecker returns the checker handed to category.
func (l *lateReferences) categoryChecker() category.ReferenceChecker {
	return lateCategoryChecker{l}
}

type lateAccountChecker struct{ l *lateReferences }

func (c lateAccountChecker) HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error) {
	if c.l.accounts == nil {
		return false, errReferencesNotBound
	}
	return c.l.accounts.HasActiveReferences(ctx, userID, id)
}

type lateCategoryChecker struct{ l *lateReferences }

func (c lateCategoryChecker) HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error) {
	if c.l.categories == nil {
		return false, errReferencesNotBound
	}
	return c.l.categories.HasActiveReferences(ctx, userID, id)
}
