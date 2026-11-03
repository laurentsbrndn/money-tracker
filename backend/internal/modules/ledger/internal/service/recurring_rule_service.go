package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/dto"
	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/syncbase"
)

// RecurringRuleService validates and stores recurring rules (docs/BUSINESS_RULES.md §5, §6, §7).
type RecurringRuleService struct {
	repo    *repository.RecurringRuleRepository
	refs    references
	billing billing.Entitlements
	clock   clock.Clock
}

// NewRecurringRuleService builds the service.
func NewRecurringRuleService(repo *repository.RecurringRuleRepository, accounts wallet.Accounts, categories category.Categories, bill billing.Entitlements, clk clock.Clock) *RecurringRuleService {
	return &RecurringRuleService{repo: repo, refs: references{accounts: accounts, categories: categories}, billing: bill, clock: clk}
}

// Upsert validates a pushed recurring rule and writes the whole row. Shape rules are checked
// first, then references, then the plan: creating, reviving, or unpausing a rule needs premium.
func (s *RecurringRuleService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.RecurringRuleRow](c.Data)
	if rej != nil {
		return rej
	}
	if in.ID != c.ID {
		return syncbase.InvalidField("id", "id di data harus sama dengan id entri")
	}
	if in.DeletedAt != nil {
		return syncbase.InvalidField("deleted_at", "upsert tidak boleh berisi deleted_at; gunakan op delete")
	}
	if rej := validateRuleShape(in); rej != nil {
		return rej
	}
	if rej, err := s.checkReferences(ctx, userID, in); rej != nil || err != nil {
		if rej != nil {
			return rej
		}
		return err
	}

	existing, err := s.repo.Find(ctx, userID, c.ID)
	if err != nil {
		return err
	}
	// "Aktif" means a row that starts generating: new, revived from a tombstone, or unpaused.
	becomesActive := existing == nil || existing.DeletedAt != nil || (existing.IsPaused && !*in.IsPaused)
	if becomesActive {
		premium, err := s.billing.IsPremium(ctx, userID)
		if err != nil {
			return err
		}
		if !billing.RecurringAllowed(premium) {
			return syncbase.PlanLimit("Transaksi berulang hanya untuk paket premium")
		}
	}

	now := s.clock.Now()
	row := &model.RecurringRule{
		Columns: syncbase.Columns{
			ID: c.ID, UserID: userID, CreatedAt: *in.CreatedAt, UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		Type: in.Type, Amount: *in.Amount, AccountID: in.AccountID, ToAccountID: in.ToAccountID,
		CategoryID: in.CategoryID, Allocation: in.Allocation, Source: in.Source, Note: in.Note,
		Frequency: in.Frequency, IntervalCount: *in.IntervalCount,
		DayOfWeek: in.DayOfWeek, DayOfMonth: in.DayOfMonth, MonthOfYear: in.MonthOfYear,
		StartDate: *in.StartDate, EndDate: in.EndDate, Mode: in.Mode, IsPaused: *in.IsPaused,
		LastGeneratedDate: in.LastGeneratedDate,
	}
	return s.repo.Save(ctx, row, now)
}

// Delete tombstones a recurring rule. Transactions it already created stay.
func (s *RecurringRuleService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	return s.repo.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

// PauseActive pauses the user's live rules (premium ended). Call it under the user's lock.
func (s *RecurringRuleService) PauseActive(ctx context.Context, userID uuid.UUID, now time.Time) (int, error) {
	return s.repo.PauseActive(ctx, userID, now)
}

// PurgeUser deletes every recurring rule of the user.
func (s *RecurringRuleService) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return s.repo.DeleteByUser(ctx, userID)
}

// validateRuleShape applies the rules that need no database lookup: the transaction template
// (as for a transaction of the same type) and the schedule fields of the frequency.
func validateRuleShape(in dto.RecurringRuleRow) *syncbase.RejectError {
	amount := *in.Amount
	if !syncbase.AmountInRange(amount) || amount <= 0 {
		return syncbase.InvalidField("amount", "nominal harus lebih dari 0 dan dalam batas")
	}
	if in.Note != nil && !syncbase.TextLen(*in.Note, 0, 255) {
		return syncbase.InvalidField("note", "catatan maksimal 255 karakter")
	}
	if in.Source != nil && !syncbase.TextLen(*in.Source, 0, 100) {
		return syncbase.InvalidField("source", "sumber maksimal 100 karakter")
	}
	switch in.Type {
	case model.TypeTransfer:
		if in.ToAccountID == nil {
			return syncbase.InvalidField("to_account_id", "wajib diisi untuk transfer")
		}
		if *in.ToAccountID == in.AccountID {
			return syncbase.InvalidField("to_account_id", "akun tujuan harus berbeda dari akun asal")
		}
		if rej := firstSet(field{"category_id", in.CategoryID != nil}, field{"allocation", in.Allocation != nil}, field{"source", in.Source != nil}); rej != nil {
			return rej
		}
	case model.TypeExpense:
		if in.CategoryID == nil {
			return syncbase.InvalidField("category_id", "wajib diisi untuk expense")
		}
		if in.Allocation == nil {
			return syncbase.InvalidField("allocation", "wajib diisi untuk expense")
		}
		if rej := firstSet(field{"to_account_id", in.ToAccountID != nil}, field{"source", in.Source != nil}); rej != nil {
			return rej
		}
	case model.TypeIncome:
		if rej := firstSet(field{"allocation", in.Allocation != nil}, field{"to_account_id", in.ToAccountID != nil}); rej != nil {
			return rej
		}
	}
	if in.EndDate != nil && in.EndDate.Before(*in.StartDate) {
		return syncbase.InvalidField("end_date", "tanggal selesai tidak boleh sebelum tanggal mulai")
	}
	return validateSchedule(in)
}

// validateSchedule requires exactly the schedule fields of the frequency (docs/DATA_MODEL.md §5).
func validateSchedule(in dto.RecurringRuleRow) *syncbase.RejectError {
	hasDow, hasDom, hasMoy := in.DayOfWeek != nil, in.DayOfMonth != nil, in.MonthOfYear != nil
	switch in.Frequency {
	case model.FrequencyDaily:
		return firstSet(field{"day_of_week", hasDow}, field{"day_of_month", hasDom}, field{"month_of_year", hasMoy})
	case model.FrequencyWeekly:
		if !hasDow || *in.DayOfWeek < 1 || *in.DayOfWeek > 7 {
			return syncbase.InvalidField("day_of_week", "wajib diisi 1-7 untuk weekly")
		}
		return firstSet(field{"day_of_month", hasDom}, field{"month_of_year", hasMoy})
	case model.FrequencyMonthly:
		if !hasDom || *in.DayOfMonth < 1 || *in.DayOfMonth > 31 {
			return syncbase.InvalidField("day_of_month", "wajib diisi 1-31 untuk monthly")
		}
		return firstSet(field{"day_of_week", hasDow}, field{"month_of_year", hasMoy})
	case model.FrequencyYearly:
		if !hasMoy || *in.MonthOfYear < 1 || *in.MonthOfYear > 12 {
			return syncbase.InvalidField("month_of_year", "wajib diisi 1-12 untuk yearly")
		}
		// 29 Feb is allowed (28 Feb in other years); 30 Feb and 31 Apr never occur.
		if !hasDom || *in.DayOfMonth < 1 || int(*in.DayOfMonth) > civil.DaysInMonth(2024, time.Month(*in.MonthOfYear)) {
			return syncbase.InvalidField("day_of_month", "tanggal tidak ada di bulan itu")
		}
		return firstSet(field{"day_of_week", hasDow})
	}
	return syncbase.InvalidField("frequency", "frekuensi tidak dikenal")
}

// checkReferences validates the template's accounts and category. The start date may not
// precede an account's opening date, like the dates of the transactions it will create.
func (s *RecurringRuleService) checkReferences(ctx context.Context, userID uuid.UUID, in dto.RecurringRuleRow) (*syncbase.RejectError, error) {
	if rej, err := s.refs.checkAccount(ctx, userID, "account_id", in.AccountID, "start_date", *in.StartDate); rej != nil || err != nil {
		return rej, err
	}
	if in.ToAccountID != nil {
		if rej, err := s.refs.checkAccount(ctx, userID, "to_account_id", *in.ToAccountID, "start_date", *in.StartDate); rej != nil || err != nil {
			return rej, err
		}
	}
	if in.CategoryID != nil {
		return s.refs.checkCategory(ctx, userID, *in.CategoryID, in.Type)
	}
	return nil, nil
}
