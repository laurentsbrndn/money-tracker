package ledger

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/modules/ledger/internal/synchandler"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the ledger module.
type Deps struct {
	DB       *database.TxManager
	Clock    clock.Clock
	Wallet   wallet.Accounts
	Category category.Categories
}

// Module wires the ledger module.
type Module struct {
	db           *database.TxManager
	transactions *service.TransactionService
	accountRefs  *service.AccountReferences
	categoryRefs *service.CategoryReferences
	sync         syncbase.Handler
}

// New builds the module.
func New(d Deps) *Module {
	repo := repository.NewTransactionRepository(d.DB)
	svc := service.NewTransactionService(repo, d.Wallet, d.Category, d.Clock)
	return &Module{
		db:           d.DB,
		transactions: svc,
		accountRefs:  service.NewAccountReferences(repo),
		categoryRefs: service.NewCategoryReferences(repo),
		sync:         synchandler.NewTransactionHandler(repo, svc),
	}
}

// API returns the public interface of the module.
func (m *Module) API() Ledger {
	return m
}

// AccountReferences implements Ledger.
func (m *Module) AccountReferences() wallet.ReferenceChecker {
	return m.accountRefs
}

// CategoryReferences implements Ledger.
func (m *Module) CategoryReferences() category.ReferenceChecker {
	return m.categoryRefs
}

// RegisterSyncHandlers registers the transactions sync handler.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	r.Register(m.sync)
}

// PurgeUser permanently deletes the user's transactions under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		return m.transactions.PurgeUser(ctx, userID)
	})
}
