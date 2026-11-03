package synchandler

import (
	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/modules/wallet/internal/repository"
	"moneytracker/internal/modules/wallet/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewBalanceSnapshotHandler builds the sync handler of balance snapshots.
func NewBalanceSnapshotHandler(repo *repository.BalanceSnapshotRepository, svc *service.BalanceSnapshotService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.BalanceSnapshot]("balance_snapshots", repo.Repository, svc.Upsert, svc.Delete)
}
