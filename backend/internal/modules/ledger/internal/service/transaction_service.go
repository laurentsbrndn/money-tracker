// Package service holds the business rules of the ledger module.
package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/dto"
	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/syncbase"
)

const (
	currencyIDR = "IDR"
	// futureSlackDays is how far ahead a transaction may be dated (docs/BUSINESS_RULES.md §6).
	futureSlackDays = 366
)

// TransactionService validates and stores transactions (docs/BUSINESS_RULES.md §6).
type TransactionService struct {
	repo       *repository.TransactionRepository
	accounts   wallet.Accounts
	categories category.Categories
	clock      clock.Clock
}

// NewTransactionService builds the service.
func NewTransactionService(repo *repository.TransactionRepository, accounts wallet.Accounts, categories category.Categories, clk clock.Clock) *TransactionService {
	return &TransactionService{repo: repo, accounts: accounts, categories: categories, clock: clk}
}

// Upsert validates a pushed transaction and writes the whole row. Shape rules (fields per
// type, amounts, lengths) are checked before references, so a malformed change is rejected
// for good instead of being retried.
func (s *TransactionService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.TransactionRow](c.Data)
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
	if rej := validateShape(in); rej != nil {
		return rej
	}
	if in.TransactionDate.After(syncbase.LatestDate(now, futureSlackDays)) {
		return syncbase.InvalidField("transaction_date", "tanggal terlalu jauh di masa depan")
	}
	if rej, err := s.checkReferences(ctx, userID, in); err != nil || rej != nil {
		if rej != nil {
			return rej
		}
		return err
	}

	row := &model.Transaction{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		Type:                in.Type,
		Status:              in.Status,
		TransactionDate:     *in.TransactionDate,
		Amount:              *in.Amount,
		Currency:            in.Currency,
		AccountID:           in.AccountID,
		ToAccountID:         in.ToAccountID,
		CategoryID:          in.CategoryID,
		Allocation:          in.Allocation,
		Source:              in.Source,
		Note:                in.Note,
		LinkedTransactionID: in.LinkedTransactionID,
		RecurringRuleID:     in.RecurringRuleID,
	}
	return s.repo.Save(ctx, row, now)
}

// Delete tombstones a transaction.
func (s *TransactionService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	return s.repo.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

// validateShape applies the rules that need no database lookup.
func validateShape(in dto.TransactionRow) *syncbase.RejectError {
	if in.Currency != currencyIDR {
		return syncbase.InvalidField("currency", "hanya IDR yang didukung")
	}
	amount := *in.Amount
	if !syncbase.AmountInRange(amount) {
		return syncbase.InvalidField("amount", "nominal di luar batas")
	}
	if in.Note != nil && !syncbase.TextLen(*in.Note, 0, 255) {
		return syncbase.InvalidField("note", "catatan maksimal 255 karakter")
	}
	if in.Source != nil && !syncbase.TextLen(*in.Source, 0, 100) {
		return syncbase.InvalidField("source", "sumber maksimal 100 karakter")
	}
	if in.LinkedTransactionID != nil && in.Type != model.TypeExpense {
		return syncbase.InvalidField("linked_transaction_id", "hanya untuk expense")
	}

	if in.Type == model.TypeAdjustment {
		if amount == 0 {
			return syncbase.InvalidField("amount", "selisih tidak boleh 0")
		}
	} else if amount <= 0 {
		return syncbase.InvalidField("amount", "nominal harus lebih dari 0")
	}

	switch in.Type {
	case model.TypeTransfer:
		if in.ToAccountID == nil {
			return syncbase.InvalidField("to_account_id", "wajib diisi untuk transfer")
		}
		if *in.ToAccountID == in.AccountID {
			return syncbase.InvalidField("to_account_id", "akun tujuan harus berbeda dari akun asal")
		}
		return firstSet(
			field{"category_id", in.CategoryID != nil},
			field{"allocation", in.Allocation != nil},
			field{"source", in.Source != nil})
	case model.TypeExpense:
		if in.CategoryID == nil {
			return syncbase.InvalidField("category_id", "wajib diisi untuk expense")
		}
		if in.Allocation == nil {
			return syncbase.InvalidField("allocation", "wajib diisi untuk expense")
		}
		return firstSet(
			field{"to_account_id", in.ToAccountID != nil},
			field{"source", in.Source != nil})
	case model.TypeIncome:
		return firstSet(
			field{"allocation", in.Allocation != nil},
			field{"to_account_id", in.ToAccountID != nil})
	case model.TypeAdjustment:
		return firstSet(
			field{"category_id", in.CategoryID != nil},
			field{"allocation", in.Allocation != nil},
			field{"to_account_id", in.ToAccountID != nil},
			field{"source", in.Source != nil},
			field{"recurring_rule_id", in.RecurringRuleID != nil})
	}
	return nil
}

// field names a column and whether the payload sets it.
type field struct {
	name string
	set  bool
}

// firstSet rejects the first field that must be null for the transaction type but is set.
func firstSet(fields ...field) *syncbase.RejectError {
	for _, f := range fields {
		if f.set {
			return syncbase.InvalidField(f.name, "harus null untuk tipe transaksi ini")
		}
	}
	return nil
}

// checkReferences validates every row the transaction points to. It returns a rejection for
// rule violations and an error for infrastructure failures.
func (s *TransactionService) checkReferences(ctx context.Context, userID uuid.UUID, in dto.TransactionRow) (*syncbase.RejectError, error) {
	if rej, err := s.checkAccount(ctx, userID, "account_id", in.AccountID, *in.TransactionDate); rej != nil || err != nil {
		return rej, err
	}
	if in.ToAccountID != nil {
		if rej, err := s.checkAccount(ctx, userID, "to_account_id", *in.ToAccountID, *in.TransactionDate); rej != nil || err != nil {
			return rej, err
		}
	}
	if in.CategoryID != nil {
		if rej, err := s.checkCategory(ctx, userID, *in.CategoryID, in.Type); rej != nil || err != nil {
			return rej, err
		}
	}
	if in.LinkedTransactionID != nil {
		return s.checkLinked(ctx, userID, in)
	}
	return nil, nil
}

// checkAccount requires a live account of the user whose opening date is not after date.
// An account that is missing or owned by someone else is reference_missing; archived
// accounts are fine, deleted ones are not.
func (s *TransactionService) checkAccount(ctx context.Context, userID uuid.UUID, fieldName string, id uuid.UUID, date civil.Date) (*syncbase.RejectError, error) {
	account, err := s.accounts.Get(ctx, userID, id)
	if err != nil {
		if errors.Is(err, wallet.ErrNotFound) {
			return syncbase.ReferenceMissing("akun belum ada"), nil
		}
		return nil, err
	}
	if account.IsDeleted {
		return syncbase.InvalidField(fieldName, "akun sudah dihapus"), nil
	}
	if date.Before(account.OpeningDate) {
		return syncbase.InvalidField("transaction_date", "tanggal sebelum tanggal saldo awal akun"), nil
	}
	return nil, nil
}

// checkCategory requires a live category of the right kind: expense transactions use expense
// categories, income transactions use income categories.
func (s *TransactionService) checkCategory(ctx context.Context, userID, id uuid.UUID, txType string) (*syncbase.RejectError, error) {
	cat, err := s.categories.Get(ctx, userID, id)
	if err != nil {
		if errors.Is(err, category.ErrNotFound) {
			return syncbase.ReferenceMissing("kategori belum ada"), nil
		}
		return nil, err
	}
	if cat.IsDeleted {
		return syncbase.InvalidField("category_id", "kategori sudah dihapus"), nil
	}
	if cat.Type != txType {
		return syncbase.InvalidField("category_id", "tipe kategori tidak sesuai dengan tipe transaksi"), nil
	}
	return nil, nil
}

// checkLinked requires the linked row to be a transfer of the user (the fee's parent).
func (s *TransactionService) checkLinked(ctx context.Context, userID uuid.UUID, in dto.TransactionRow) (*syncbase.RejectError, error) {
	if *in.LinkedTransactionID == in.ID {
		return syncbase.InvalidField("linked_transaction_id", "tidak boleh merujuk dirinya sendiri"), nil
	}
	linked, err := s.repo.Find(ctx, userID, *in.LinkedTransactionID)
	if err != nil {
		return nil, err
	}
	if linked == nil {
		return syncbase.ReferenceMissing("transfer terkait belum ada"), nil
	}
	if linked.Type != model.TypeTransfer {
		return syncbase.InvalidField("linked_transaction_id", "harus merujuk transfer"), nil
	}
	return nil, nil
}

// AccountReferences reports whether live transactions use an account.
type AccountReferences struct {
	repo *repository.TransactionRepository
}

// NewAccountReferences builds the checker.
func NewAccountReferences(repo *repository.TransactionRepository) *AccountReferences {
	return &AccountReferences{repo: repo}
}

// HasActiveReferences implements wallet.ReferenceChecker.
func (r *AccountReferences) HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error) {
	return r.repo.UsesAccount(ctx, userID, id)
}

// CategoryReferences reports whether live transactions use a category.
type CategoryReferences struct {
	repo *repository.TransactionRepository
}

// NewCategoryReferences builds the checker.
func NewCategoryReferences(repo *repository.TransactionRepository) *CategoryReferences {
	return &CategoryReferences{repo: repo}
}

// HasActiveReferences implements category.ReferenceChecker.
func (r *CategoryReferences) HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error) {
	return r.repo.UsesCategory(ctx, userID, id)
}

// PurgeUser deletes every transaction of the user.
func (s *TransactionService) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return s.repo.DeleteByUser(ctx, userID)
}
