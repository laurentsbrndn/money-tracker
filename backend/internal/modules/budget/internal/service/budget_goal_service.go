// Package service holds the business rules of the budget module.
package service

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/budget/internal/dto"
	"moneytracker/internal/modules/budget/internal/model"
	"moneytracker/internal/modules/budget/internal/repository"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/idgen"
	"moneytracker/internal/platform/syncbase"
)

// BudgetGoalService validates and stores budget goals (docs/BUSINESS_RULES.md §6).
type BudgetGoalService struct {
	repo  *repository.BudgetGoalRepository
	clock clock.Clock
}

// NewBudgetGoalService builds the service.
func NewBudgetGoalService(repo *repository.BudgetGoalRepository, clk clock.Clock) *BudgetGoalService {
	return &BudgetGoalService{repo: repo, clock: clk}
}

// Upsert validates a pushed goal and writes the whole row. The ID must be the deterministic
// one for the effective month, so two devices that set the same month's goal write one row.
func (s *BudgetGoalService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.BudgetGoalRow](c.Data)
	if rej != nil {
		return rej
	}
	if in.ID != c.ID {
		return syncbase.InvalidField("id", "id di data harus sama dengan id entri")
	}
	if in.DeletedAt != nil {
		return syncbase.InvalidField("deleted_at", "upsert tidak boleh berisi deleted_at; gunakan op delete")
	}
	if in.EffectiveMonth.Day() != 1 {
		return syncbase.InvalidField("effective_month", "harus tanggal 1")
	}
	month := domainrules.MonthOf(*in.EffectiveMonth)
	if want := idgen.BudgetGoalID(userID, month.String()); c.ID != want {
		return syncbase.InvalidField("id", "id harus UUIDv5 dari user dan bulan efektif")
	}
	if *in.NeedsPct+*in.WantsPct+*in.SavingsPct != 100 {
		return syncbase.Invalid("jumlah persentase needs, wants, dan savings harus 100")
	}
	if in.PlannedIncome != nil && (*in.PlannedIncome < 0 || *in.PlannedIncome > syncbase.MaxAmount) {
		return syncbase.InvalidField("planned_income", "harus 0 sampai batas nominal")
	}

	row := &model.BudgetGoal{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		EffectiveMonth: *in.EffectiveMonth,
		NeedsPct:       int16(*in.NeedsPct),
		WantsPct:       int16(*in.WantsPct),
		SavingsPct:     int16(*in.SavingsPct),
		PlannedIncome:  in.PlannedIncome,
	}
	return s.repo.Save(ctx, row, s.clock.Now())
}

// Delete tombstones a goal.
func (s *BudgetGoalService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	return s.repo.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

// CreateDefault creates the 50/30/20 goal of a new user for month. Run it inside the
// registration transaction.
func (s *BudgetGoalService) CreateDefault(ctx context.Context, userID uuid.UUID, month domainrules.YearMonth) error {
	now := s.clock.Now()
	row := &model.BudgetGoal{
		Columns: syncbase.Columns{
			ID:        idgen.BudgetGoalID(userID, month.String()),
			UserID:    userID,
			CreatedAt: syncbase.NewTime(now),
			UpdatedAt: syncbase.NewTime(now),
		},
		EffectiveMonth: month.First(),
		NeedsPct:       50,
		WantsPct:       30,
		SavingsPct:     20,
	}
	return s.repo.Save(ctx, row, now)
}

// EffectiveFor returns the goal in force for month, or false when there is none.
func (s *BudgetGoalService) EffectiveFor(ctx context.Context, userID uuid.UUID, month domainrules.YearMonth) (domainrules.BudgetGoal, bool, error) {
	goal, err := s.repo.EffectiveFor(ctx, userID, month.First())
	if err != nil || goal == nil {
		return domainrules.BudgetGoal{}, false, err
	}
	return domainrules.BudgetGoal{
		EffectiveMonth: domainrules.MonthOf(goal.EffectiveMonth),
		NeedsPct:       int64(goal.NeedsPct),
		WantsPct:       int64(goal.WantsPct),
		SavingsPct:     int64(goal.SavingsPct),
		PlannedIncome:  goal.PlannedIncome,
	}, true, nil
}

// PurgeUser deletes every goal of the user.
func (s *BudgetGoalService) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return s.repo.DeleteByUser(ctx, userID)
}
