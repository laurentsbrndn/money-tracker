package service

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/platform/civil"
)

// AggregateQuery selects what Aggregates computes.
type AggregateQuery struct {
	// AsOf is the reference date: only transactions dated on or before it are read.
	AsOf civil.Date
	// Month is the month the per-category totals are taken for.
	Month domainrules.YearMonth
}

// CategoryTotal is the sum of one category (nil CategoryID: income without a category).
type CategoryTotal struct {
	CategoryID *uuid.UUID
	Amount     int64
}

// AggregateResult is what the report module needs from the ledger.
type AggregateResult struct {
	// Flows are the counted transactions (live, posted, dated on or before AsOf) summed per
	// day, type, account pair and allocation, in the shape domainrules consumes. Summing
	// does not change any rule result: every rule is additive over amounts.
	Flows []domainrules.Transaction
	// ExpenseByCategory and IncomeByCategory are the month's totals, largest first.
	ExpenseByCategory []CategoryTotal
	IncomeByCategory  []CategoryTotal
}

// AggregateService answers read-only aggregate questions for reports.
type AggregateService struct {
	repo *repository.TransactionRepository
}

// NewAggregateService builds the service.
func NewAggregateService(repo *repository.TransactionRepository) *AggregateService {
	return &AggregateService{repo: repo}
}

// Aggregates reads the counted flows and the month's category totals of the user.
func (s *AggregateService) Aggregates(ctx context.Context, userID uuid.UUID, q AggregateQuery) (AggregateResult, error) {
	flows, err := s.Flows(ctx, userID, q.AsOf)
	if err != nil {
		return AggregateResult{}, err
	}

	expense, err := s.byCategory(ctx, userID, string(domainrules.TxExpense), q)
	if err != nil {
		return AggregateResult{}, err
	}
	income, err := s.byCategory(ctx, userID, string(domainrules.TxIncome), q)
	if err != nil {
		return AggregateResult{}, err
	}
	return AggregateResult{Flows: flows, ExpenseByCategory: expense, IncomeByCategory: income}, nil
}

func (s *AggregateService) byCategory(ctx context.Context, userID uuid.UUID, txType string, q AggregateQuery) ([]CategoryTotal, error) {
	last := q.Month.Last()
	if q.AsOf.Before(last) {
		last = q.AsOf
	}
	rows, err := s.repo.CategoryTotals(ctx, userID, txType, q.Month.First(), last)
	if err != nil {
		return nil, err
	}
	out := make([]CategoryTotal, 0, len(rows))
	for _, r := range rows {
		out = append(out, CategoryTotal{CategoryID: r.CategoryID, Amount: r.Amount})
	}
	return out, nil
}

// Flows reads the counted transactions (live, posted, dated on or before asOf) summed per day,
// type, account pair and allocation, in the shape domainrules consumes.
func (s *AggregateService) Flows(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]domainrules.Transaction, error) {
	rows, err := s.repo.Flows(ctx, userID, asOf)
	if err != nil {
		return nil, err
	}
	flows := make([]domainrules.Transaction, 0, len(rows))
	for _, r := range rows {
		tx := domainrules.Transaction{
			Type:      domainrules.TransactionType(r.Type),
			Status:    domainrules.StatusPosted,
			Date:      r.TransactionDate,
			Amount:    r.Amount,
			AccountID: r.AccountID.String(),
		}
		if r.ToAccountID != nil {
			tx.ToAccountID = r.ToAccountID.String()
		}
		if r.Allocation != nil {
			tx.Allocation = domainrules.Allocation(*r.Allocation)
		}
		flows = append(flows, tx)
	}
	return flows, nil
}
