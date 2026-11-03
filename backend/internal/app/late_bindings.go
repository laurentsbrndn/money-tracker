package app

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
)

var errNotBound = errors.New("dependency not bound")

// latePremiumEnded breaks a construction cycle: billing calls it when premium ends, and the
// implementation is ledger.PauseRules, while ledger needs billing to be built first. Build binds
// it before the server accepts any connection.
type latePremiumEnded struct {
	handler billing.PremiumEndedHandler
}

// OnPremiumEnded implements billing.PremiumEndedHandler.
func (l *latePremiumEnded) OnPremiumEnded(ctx context.Context, userID uuid.UUID) error {
	if l.handler == nil {
		return errNotBound
	}
	return l.handler.OnPremiumEnded(ctx, userID)
}

// ledgerPauser adapts ledger.PauseRules to billing.PremiumEndedHandler.
type ledgerPauser struct {
	pause func(ctx context.Context, userID uuid.UUID) error
}

// OnPremiumEnded implements billing.PremiumEndedHandler.
func (p ledgerPauser) OnPremiumEnded(ctx context.Context, userID uuid.UUID) error {
	return p.pause(ctx, userID)
}

// lateTimezones breaks a construction cycle: ledger needs a timezone source, which is identity's
// settings, while identity is built after ledger (its onboarding seeds through other modules).
type lateTimezones struct {
	source interface {
		Timezone(ctx context.Context, userID uuid.UUID) (string, error)
	}
}

// Timezone implements ledger.Timezones.
func (l *lateTimezones) Timezone(ctx context.Context, userID uuid.UUID) (string, error) {
	if l.source == nil {
		return "", errNotBound
	}
	return l.source.Timezone(ctx, userID)
}
