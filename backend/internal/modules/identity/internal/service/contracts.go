package service

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Onboarder seeds the data of a new user inside the registration transaction
// (docs/BACKEND.md §6.1). It is implemented by the composition root.
type Onboarder interface {
	Onboard(ctx context.Context, userID uuid.UUID, timezone string) error
}

// Entitlement is the premium status shown by GET /me. It mirrors the billing entitlement;
// identity cannot import billing, so the composition root adapts one to the other.
type Entitlement struct {
	Premium   bool
	ExpiresAt *time.Time
	WillRenew bool
	ProductID string
	Store     string
}

// EntitlementReader returns the entitlement of a user.
type EntitlementReader interface {
	Entitlement(ctx context.Context, userID uuid.UUID) (Entitlement, error)
}
