package category

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/category/internal/repository"
	"moneytracker/internal/modules/category/internal/service"
	"moneytracker/internal/modules/category/internal/synchandler"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the category module.
type Deps struct {
	DB      *database.TxManager
	Clock   clock.Clock
	Billing billing.Entitlements
	// References blocks deleting categories that live transactions still use.
	References ReferenceChecker
}

// Module wires the category module.
type Module struct {
	db      *database.TxManager
	service *service.CategoryService
	sync    syncbase.Handler
}

// New builds the module.
func New(d Deps) *Module {
	repo := repository.NewCategoryRepository(d.DB)
	svc := service.NewCategoryService(repo, d.Billing, d.References, d.Clock)
	return &Module{db: d.DB, service: svc, sync: synchandler.NewCategoryHandler(repo, svc)}
}

// API returns the public interface of the module.
func (m *Module) API() Categories {
	return m.service
}

// RegisterSyncHandlers registers the categories sync handler.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	r.Register(m.sync)
}

// PurgeUser permanently deletes the user's categories under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		return m.service.PurgeUser(ctx, userID)
	})
}
