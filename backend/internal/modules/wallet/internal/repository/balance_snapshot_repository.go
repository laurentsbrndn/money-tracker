package repository

import (
	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// BalanceSnapshotRepository stores balance snapshots.
type BalanceSnapshotRepository struct {
	*syncbase.Repository[model.BalanceSnapshot, *model.BalanceSnapshot]
}

// NewBalanceSnapshotRepository builds the repository.
func NewBalanceSnapshotRepository(db *database.TxManager) *BalanceSnapshotRepository {
	return &BalanceSnapshotRepository{Repository: syncbase.NewRepository[model.BalanceSnapshot](db)}
}
