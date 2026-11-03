package service

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/wallet/internal/dto"
	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/modules/wallet/internal/repository"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/syncbase"
)

// BalanceSnapshotService validates and stores balance snapshots (docs/BUSINESS_RULES.md §6).
type BalanceSnapshotService struct {
	snapshots *repository.BalanceSnapshotRepository
	accounts  *repository.AccountRepository
	clock     clock.Clock
}

// NewBalanceSnapshotService builds the service.
func NewBalanceSnapshotService(snapshots *repository.BalanceSnapshotRepository, accounts *repository.AccountRepository, clk clock.Clock) *BalanceSnapshotService {
	return &BalanceSnapshotService{snapshots: snapshots, accounts: accounts, clock: clk}
}

// Upsert validates a pushed snapshot and writes the whole row.
func (s *BalanceSnapshotService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.BalanceSnapshotRow](c.Data)
	if rej != nil {
		return rej
	}
	if in.ID != c.ID {
		return syncbase.InvalidField("id", "id di data harus sama dengan id entri")
	}
	if in.DeletedAt != nil {
		return syncbase.InvalidField("deleted_at", "upsert tidak boleh berisi deleted_at; gunakan op delete")
	}
	now := s.clock.Now()
	if !syncbase.AmountInRange(*in.Amount) {
		return syncbase.InvalidField("amount", "nominal di luar batas")
	}
	if in.Note != nil && !syncbase.TextLen(*in.Note, 0, 255) {
		return syncbase.InvalidField("note", "catatan maksimal 255 karakter")
	}

	// A missing account, or one that belongs to someone else, is reference_missing: the
	// account may simply arrive in a later push.
	account, err := s.accounts.Find(ctx, userID, in.AccountID)
	if err != nil {
		return err
	}
	if account == nil {
		return syncbase.ReferenceMissing("akun belum ada")
	}
	if account.DeletedAt != nil {
		return syncbase.InvalidField("account_id", "akun sudah dihapus")
	}
	if in.SnapshotDate.Before(account.OpeningDate) {
		return syncbase.InvalidField("snapshot_date", "tanggal sebelum tanggal saldo awal akun")
	}
	if in.SnapshotDate.After(syncbase.LatestDate(now, openingDateSlackDays)) {
		return syncbase.InvalidField("snapshot_date", "tanggal tidak boleh di masa depan")
	}

	row := &model.BalanceSnapshot{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		AccountID:    in.AccountID,
		SnapshotDate: *in.SnapshotDate,
		Amount:       *in.Amount,
		Note:         in.Note,
	}
	return s.snapshots.Save(ctx, row, now)
}

// Delete tombstones a snapshot.
func (s *BalanceSnapshotService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	return s.snapshots.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

// Latest returns each account's newest live snapshot rows on or before asOf in the shape of
// domainrules (docs/BUSINESS_RULES.md §4.3). Accounts without a snapshot are absent.
func (s *BalanceSnapshotService) Latest(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]domainrules.BalanceSnapshot, error) {
	rows, err := s.snapshots.Latest(ctx, userID, asOf)
	if err != nil {
		return nil, err
	}
	out := make([]domainrules.BalanceSnapshot, 0, len(rows))
	for i := range rows {
		out = append(out, domainrules.BalanceSnapshot{
			AccountID: rows[i].AccountID.String(),
			Date:      rows[i].SnapshotDate,
			Amount:    rows[i].Amount,
			UpdatedAt: rows[i].UpdatedAt.Std(),
		})
	}
	return out, nil
}
