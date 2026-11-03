// Package service holds the business rules of the wallet module.
package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/wallet/internal/dto"
	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/modules/wallet/internal/repository"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/idgen"
	"moneytracker/internal/platform/syncbase"
)

const (
	currencyIDR = "IDR"
	// openingDateSlackDays lets users ahead of UTC (WIB) record "today" (see syncbase.LatestDate).
	openingDateSlackDays = 1
)

// ErrNotFound is returned by Get for an unknown account.
var ErrNotFound = errors.New("account not found")

// ReferenceChecker tells whether live transactions still use an account. It is implemented by
// ledger and injected by the composition root (ledger depends on wallet, not the reverse).
type ReferenceChecker interface {
	HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error)
}

// Account is the public view of an account for other modules.
type Account struct {
	ID          uuid.UUID
	Name        string
	Type        string
	OpeningDate civil.Date
	IsArchived  bool
	IsDeleted   bool
}

// AccountService validates and stores accounts (docs/BUSINESS_RULES.md §6, §7).
type AccountService struct {
	accounts  *repository.AccountRepository
	snapshots *repository.BalanceSnapshotRepository
	billing   billing.Entitlements
	refs      ReferenceChecker
	clock     clock.Clock
}

// NewAccountService builds the service.
func NewAccountService(
	accounts *repository.AccountRepository,
	snapshots *repository.BalanceSnapshotRepository,
	bill billing.Entitlements,
	refs ReferenceChecker,
	clk clock.Clock,
) *AccountService {
	return &AccountService{accounts: accounts, snapshots: snapshots, billing: bill, refs: refs, clock: clk}
}

// Upsert validates a pushed account and writes the whole row.
func (s *AccountService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.AccountRow](c.Data)
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
	if !syncbase.TextLen(in.Name, 1, 50) {
		return syncbase.InvalidField("name", "nama harus 1-50 karakter")
	}
	if in.Currency != currencyIDR {
		return syncbase.InvalidField("currency", "hanya IDR yang didukung")
	}
	if !syncbase.AmountInRange(*in.OpeningBalance) {
		return syncbase.InvalidField("opening_balance", "nominal di luar batas")
	}
	if in.OpeningDate.After(syncbase.LatestDate(now, openingDateSlackDays)) {
		return syncbase.InvalidField("opening_date", "tanggal tidak boleh di masa depan")
	}

	existing, err := s.accounts.Find(ctx, userID, c.ID)
	if err != nil {
		return err
	}

	// The account limit applies when a row becomes active: new, revived from a tombstone, or
	// un-archived. Plain updates of an active account are never blocked.
	wasActive := existing != nil && existing.DeletedAt == nil && existing.ArchivedAt == nil
	if in.ArchivedAt == nil && !wasActive {
		premium, err := s.billing.IsPremium(ctx, userID)
		if err != nil {
			return err
		}
		active, err := s.accounts.CountActive(ctx, userID, c.ID)
		if err != nil {
			return err
		}
		if billing.AccountLimitReached(premium, active) {
			return syncbase.PlanLimit("Batas akun paket gratis tercapai")
		}
	}

	row := &model.Account{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		Name:           in.Name,
		Type:           in.Type,
		ProviderKey:    in.ProviderKey,
		Currency:       in.Currency,
		OpeningBalance: *in.OpeningBalance,
		OpeningDate:    *in.OpeningDate,
		IncludeInTotal: *in.IncludeInTotal,
		SortOrder:      *in.SortOrder,
		ArchivedAt:     in.ArchivedAt,
	}
	return s.accounts.Save(ctx, row, now)
}

// Delete tombstones an account unless live transactions still use it (archive instead).
func (s *AccountService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	used, err := s.refs.HasActiveReferences(ctx, userID, c.ID)
	if err != nil {
		return err
	}
	if used {
		return syncbase.Invalid("akun masih dipakai transaksi; arsipkan saja")
	}
	return s.accounts.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

// Get returns the user's account, deleted ones included (flagged), or ErrNotFound.
func (s *AccountService) Get(ctx context.Context, userID, id uuid.UUID) (Account, error) {
	row, err := s.accounts.Find(ctx, userID, id)
	if err != nil {
		return Account{}, err
	}
	if row == nil {
		return Account{}, ErrNotFound
	}
	return toAccount(row), nil
}

// List returns the user's live accounts.
func (s *AccountService) List(ctx context.Context, userID uuid.UUID) ([]Account, error) {
	rows, err := s.accounts.List(ctx, userID)
	if err != nil {
		return nil, err
	}
	out := make([]Account, 0, len(rows))
	for i := range rows {
		out = append(out, toAccount(&rows[i]))
	}
	return out, nil
}

// CountActive returns the number of accounts that are neither deleted nor archived.
func (s *AccountService) CountActive(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.accounts.CountActive(ctx, userID, uuid.Nil)
}

// CreateCash creates the Cash account of a new user with its first balance snapshot
// (docs/BUSINESS_RULES.md §2.2, §2.3). Run it inside the registration transaction.
func (s *AccountService) CreateCash(ctx context.Context, userID uuid.UUID, openingDate civil.Date) error {
	now := s.clock.Now()
	accountID, err := idgen.NewV7()
	if err != nil {
		return err
	}
	snapshotID, err := idgen.NewV7()
	if err != nil {
		return err
	}
	account := &model.Account{
		Columns: syncbase.Columns{
			ID: accountID, UserID: userID, CreatedAt: syncbase.NewTime(now), UpdatedAt: syncbase.NewTime(now),
		},
		Name:           "Cash",
		Type:           model.TypeCash,
		Currency:       currencyIDR,
		OpeningBalance: 0,
		OpeningDate:    openingDate,
		IncludeInTotal: true,
		SortOrder:      0,
	}
	if err := s.accounts.Save(ctx, account, now); err != nil {
		return err
	}
	snapshot := &model.BalanceSnapshot{
		Columns: syncbase.Columns{
			ID: snapshotID, UserID: userID, CreatedAt: syncbase.NewTime(now), UpdatedAt: syncbase.NewTime(now),
		},
		AccountID:    accountID,
		SnapshotDate: openingDate,
		Amount:       0,
	}
	return s.snapshots.Save(ctx, snapshot, now)
}

// PurgeUser deletes the user's snapshots, then accounts (snapshots reference accounts).
func (s *AccountService) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	if err := s.snapshots.DeleteByUser(ctx, userID); err != nil {
		return err
	}
	return s.accounts.DeleteByUser(ctx, userID)
}

func toAccount(row *model.Account) Account {
	return Account{
		ID:          row.ID,
		Name:        row.Name,
		Type:        row.Type,
		OpeningDate: row.OpeningDate,
		IsArchived:  row.ArchivedAt != nil,
		IsDeleted:   row.DeletedAt != nil,
	}
}
