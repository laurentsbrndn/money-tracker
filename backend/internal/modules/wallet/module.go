package wallet

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/wallet/internal/repository"
	"moneytracker/internal/modules/wallet/internal/service"
	"moneytracker/internal/modules/wallet/internal/synchandler"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the wallet module.
type Deps struct {
	DB      *database.TxManager
	Clock   clock.Clock
	Billing billing.Entitlements
	// References blocks deleting accounts that live transactions still use.
	References ReferenceChecker
}

// Module wires the wallet module.
type Module struct {
	db        *database.TxManager
	accounts  *service.AccountService
	snapshots *service.BalanceSnapshotService
	syncs     []syncbase.Handler
}

// New builds the module.
func New(d Deps) *Module {
	accountRepo := repository.NewAccountRepository(d.DB)
	snapshotRepo := repository.NewBalanceSnapshotRepository(d.DB)
	accounts := service.NewAccountService(accountRepo, snapshotRepo, d.Billing, d.References, d.Clock)
	snapshots := service.NewBalanceSnapshotService(snapshotRepo, accountRepo, d.Clock)
	return &Module{
		db:        d.DB,
		accounts:  accounts,
		snapshots: snapshots,
		syncs: []syncbase.Handler{
			synchandler.NewAccountHandler(accountRepo, accounts),
			synchandler.NewBalanceSnapshotHandler(snapshotRepo, snapshots),
		},
	}
}

// API returns the public interface of the module.
func (m *Module) API() Accounts {
	return m.accounts
}

// Snapshots returns the snapshot reading interface.
func (m *Module) Snapshots() Snapshots {
	return m.snapshots
}

// RegisterSyncHandlers registers the accounts and balance_snapshots sync handlers.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	for _, h := range m.syncs {
		r.Register(h)
	}
}

// PurgeUser permanently deletes the user's accounts and snapshots under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		return m.accounts.PurgeUser(ctx, userID)
	})
}
