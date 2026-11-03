package app

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/budget"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/identity"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/clock"
)

// onboarder seeds the data of a new user (docs/DATA_MODEL.md §9). Identity calls it inside the
// registration transaction, which already holds the user lock, so the user and the whole seed
// commit together or not at all.
//
// settings is bound after the identity module is built: identity needs an Onboarder to be
// constructed, and the Onboarder needs identity's settings API.
type onboarder struct {
	settings   identity.Settings
	categories category.Categories
	accounts   wallet.Accounts
	goals      budget.Goals
	clock      clock.Clock
}

// Onboard creates user_settings, the default categories, the Cash account with its first
// balance snapshot, and the 50/30/20 goal for the current month. "Today" and "this month" are
// taken in the timezone sent at registration.
func (o *onboarder) Onboard(ctx context.Context, userID uuid.UUID, timezone string) error {
	if o.settings == nil {
		return fmt.Errorf("onboarder: settings not bound")
	}
	today, err := domainrules.Today(o.clock.Now(), timezone)
	if err != nil {
		return fmt.Errorf("onboard: %w", err)
	}
	if err := o.settings.CreateDefault(ctx, userID, timezone); err != nil {
		return fmt.Errorf("seed user settings: %w", err)
	}
	if err := o.categories.SeedDefaults(ctx, userID); err != nil {
		return fmt.Errorf("seed categories: %w", err)
	}
	if err := o.accounts.CreateCash(ctx, userID, today); err != nil {
		return fmt.Errorf("seed cash account: %w", err)
	}
	if err := o.goals.CreateDefault(ctx, userID, domainrules.MonthOf(today)); err != nil {
		return fmt.Errorf("seed budget goal: %w", err)
	}
	return nil
}
