package budget

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/budget/internal/repository"
	"moneytracker/internal/modules/budget/internal/service"
	"moneytracker/internal/modules/budget/internal/synchandler"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the budget module.
type Deps struct {
	DB    *database.TxManager
	Clock clock.Clock
}

// Module wires the budget module.
type Module struct {
	db      *database.TxManager
	service *service.BudgetGoalService
	sync    syncbase.Handler
}

// New builds the module.
func New(d Deps) *Module {
	repo := repository.NewBudgetGoalRepository(d.DB)
	svc := service.NewBudgetGoalService(repo, d.Clock)
	return &Module{db: d.DB, service: svc, sync: synchandler.NewBudgetGoalHandler(repo, svc)}
}

// API returns the public interface of the module.
func (m *Module) API() Goals {
	return m.service
}

// RegisterSyncHandlers registers the budget_goals sync handler.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	r.Register(m.sync)
}

// PurgeUser permanently deletes the user's goals under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		return m.service.PurgeUser(ctx, userID)
	})
}
