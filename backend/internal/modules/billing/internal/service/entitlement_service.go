package service

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Entitlement is the premium status of a user.
type Entitlement struct {
	Premium   bool
	ExpiresAt *time.Time
	WillRenew bool
	ProductID string
	Store     string
}

// EntitlementService answers premium questions.
//
// Temporary (Phase 1): every user is on the free plan. Phase 3 replaces this with the
// entitlements table fed by the RevenueCat webhook.
type EntitlementService struct{}

// NewEntitlementService builds the service.
func NewEntitlementService() *EntitlementService {
	return &EntitlementService{}
}

// IsPremium reports whether the user has an active premium entitlement.
func (s *EntitlementService) IsPremium(ctx context.Context, userID uuid.UUID) (bool, error) {
	ent, err := s.Get(ctx, userID)
	if err != nil {
		return false, err
	}
	return ent.Premium, nil
}

// Get returns the user's entitlement.
func (s *EntitlementService) Get(_ context.Context, _ uuid.UUID) (Entitlement, error) {
	return Entitlement{Premium: false, ExpiresAt: nil, WillRenew: false}, nil
}
