package billing

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing/internal/service"
)

// Module wires billing. Temporary: no tables and no routes until Phase 3 (RevenueCat).
type Module struct {
	entitlements *service.EntitlementService
}

// New builds the module.
func New() *Module {
	return &Module{entitlements: service.NewEntitlementService()}
}

// API returns the public interface of the module.
func (m *Module) API() Entitlements {
	return m.entitlements
}

// PurgeUser deletes the user's billing data. Nothing is stored yet; Phase 3 removes
// subscriptions, entitlements, and billing events here.
func (m *Module) PurgeUser(_ context.Context, _ uuid.UUID) error {
	return nil
}
