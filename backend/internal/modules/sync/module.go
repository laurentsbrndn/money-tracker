package sync

import (
	"context"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/sync/internal/handler"
	"moneytracker/internal/modules/sync/internal/repository"
	"moneytracker/internal/modules/sync/internal/service"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// Deps are the dependencies of the sync module.
type Deps struct {
	DB       *database.TxManager
	Clock    clock.Clock
	Billing  billing.Entitlements
	Registry *Registry
}

// Module wires the sync module.
type Module struct {
	keys    *repository.IdempotencyKeyRepository
	handler *handler.SyncHandler
}

// New builds the module.
func New(d Deps) *Module {
	keys := repository.NewIdempotencyKeyRepository(d.DB)
	return &Module{
		keys: keys,
		handler: handler.NewSyncHandler(
			service.NewPushService(d.DB, d.Registry, keys, d.Clock),
			service.NewPullService(d.DB, d.Registry, d.Billing, d.Clock),
		),
	}
}

// RegisterRoutes mounts POST /sync/push and GET /sync/pull on the (guarded) /v1 group.
func (m *Module) RegisterRoutes(v1 fiber.Router) {
	v1.Post("/sync/push", m.handler.Push)
	v1.Get("/sync/pull", m.handler.Pull)
}

// PurgeUser deletes the user's idempotency keys.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.keys.DeleteByUser(ctx, userID)
}
