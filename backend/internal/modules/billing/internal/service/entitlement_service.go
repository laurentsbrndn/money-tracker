package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing/internal/model"
	"moneytracker/internal/modules/billing/internal/repository"
	"moneytracker/internal/platform/clock"
)

// Entitlement is the premium status of a user.
type Entitlement struct {
	Premium   bool
	ExpiresAt *time.Time
	WillRenew bool
	ProductID string
	Store     string
}

// EntitlementService answers premium questions from the entitlements table, which only the
// RevenueCat webhook writes. Access is strict: an entitlement whose expires_at has passed is
// not premium even if its is_active flag has not been cleared yet (a late EXPIRATION event).
// The offline tolerance of three days belongs to the apps, not to the server.
type EntitlementService struct {
	ents  *repository.EntitlementRepository
	subs  *repository.SubscriptionRepository
	clock clock.Clock
}

// NewEntitlementService builds the service.
func NewEntitlementService(ents *repository.EntitlementRepository, subs *repository.SubscriptionRepository, clk clock.Clock) *EntitlementService {
	return &EntitlementService{ents: ents, subs: subs, clock: clk}
}

// effective reports whether the stored entitlement grants access at now.
func effective(ent *model.Entitlement, now time.Time) bool {
	return ent != nil && ent.IsActive && accessActive(ent.ExpiresAt, now)
}

// IsPremium reports whether the user has an active premium entitlement.
func (s *EntitlementService) IsPremium(ctx context.Context, userID uuid.UUID) (bool, error) {
	ent, err := s.ents.Get(ctx, userID, model.EntitlementPremium)
	if err != nil {
		return false, err
	}
	return effective(ent, s.clock.Now()), nil
}

// Get returns the entitlement shown to the app. A user who is not premium gets no expiry, so an
// app never extends a lapsed entitlement with its offline tolerance.
func (s *EntitlementService) Get(ctx context.Context, userID uuid.UUID) (Entitlement, error) {
	ent, err := s.ents.Get(ctx, userID, model.EntitlementPremium)
	if err != nil {
		return Entitlement{}, err
	}
	if !effective(ent, s.clock.Now()) {
		return Entitlement{}, nil
	}
	out := Entitlement{Premium: true, ExpiresAt: ent.ExpiresAt}
	if ent.SubscriptionID == nil {
		return out, nil
	}
	sub, err := s.subs.Get(ctx, *ent.SubscriptionID)
	if err != nil {
		return Entitlement{}, err
	}
	if sub != nil && sub.UserID == userID {
		out.WillRenew = sub.WillRenew
		out.ProductID = sub.ProductID
		out.Store = sub.Store
	}
	return out, nil
}
