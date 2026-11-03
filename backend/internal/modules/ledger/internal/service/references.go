package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/syncbase"
)

// references checks the accounts and categories a transaction or a recurring rule points to.
type references struct {
	accounts   wallet.Accounts
	categories category.Categories
}

// checkAccount requires a live account of the user whose opening date is not after date.
// An account that is missing or owned by someone else is reference_missing; archived
// accounts are fine, deleted ones are not.
func (r references) checkAccount(ctx context.Context, userID uuid.UUID, fieldName string, id uuid.UUID, dateField string, date civil.Date) (*syncbase.RejectError, error) {
	account, err := r.accounts.Get(ctx, userID, id)
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
		return syncbase.InvalidField(dateField, "tanggal sebelum tanggal saldo awal akun"), nil
	}
	return nil, nil
}

// checkCategory requires a live category of the right kind: expense transactions use expense
// categories, income transactions use income categories.
func (r references) checkCategory(ctx context.Context, userID, id uuid.UUID, txType string) (*syncbase.RejectError, error) {
	cat, err := r.categories.Get(ctx, userID, id)
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

func isNotFound(err error) bool         { return errors.Is(err, wallet.ErrNotFound) }
func isCategoryNotFound(err error) bool { return errors.Is(err, category.ErrNotFound) }
