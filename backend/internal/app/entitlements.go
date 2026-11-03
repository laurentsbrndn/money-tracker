package app

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/identity"
)

// entitlementReader adapts billing.Entitlements to identity.EntitlementReader, because
// identity may not import billing (docs/ARCHITECTURE.md §3.2).
type entitlementReader struct {
	billing billing.Entitlements
}

// Entitlement returns the billing entitlement of the user in identity's shape.
func (r entitlementReader) Entitlement(ctx context.Context, userID uuid.UUID) (identity.Entitlement, error) {
	ent, err := r.billing.Get(ctx, userID)
	if err != nil {
		return identity.Entitlement{}, err
	}
	return identity.Entitlement{
		Premium:   ent.Premium,
		ExpiresAt: ent.ExpiresAt,
		WillRenew: ent.WillRenew,
		ProductID: ent.ProductID,
		Store:     ent.Store,
	}, nil
}
