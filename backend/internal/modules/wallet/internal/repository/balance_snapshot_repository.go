package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/platform/civil"
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

// Latest returns, for every account of the user, the live snapshots dated on the account's
// newest snapshot date on or before asOf. Several rows can share that date (two devices on the
// same day); the rules pick the one with the newest updated_at.
func (r *BalanceSnapshotRepository) Latest(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]model.BalanceSnapshot, error) {
	// The inner table needs an alias: without it "balance_snapshots.account_id" would refer to
	// the inner query itself and the subquery would not be correlated per account.
	newest := r.DB(ctx).Table("balance_snapshots AS newest").
		Select("MAX(newest.snapshot_date)").
		Where("newest.user_id = ? AND newest.deleted_at IS NULL AND newest.snapshot_date <= ?", userID, asOf).
		Where("newest.account_id = balance_snapshots.account_id")
	var rows []model.BalanceSnapshot
	err := r.DB(ctx).
		Where("user_id = ? AND deleted_at IS NULL AND snapshot_date <= ?", userID, asOf).
		Where("snapshot_date = (?)", newest).
		Order("account_id, updated_at").
		Find(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("load latest snapshots: %w", err)
	}
	return rows, nil
}
