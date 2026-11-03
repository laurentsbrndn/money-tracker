package service

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/budget"
	"moneytracker/internal/modules/ledger"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// ErrPremiumRequired is returned to a free user who asks for a premium report
// (docs/BUSINESS_RULES.md §7).
var ErrPremiumRequired = errors.New("report needs premium")

// TrendMonth is one month of the trend report (docs/BUSINESS_RULES.md §4.6).
type TrendMonth struct {
	Month       domainrules.YearMonth
	Income      int64
	Expense     int64
	Surplus     int64
	Savings     int64
	Adjustments int64
}

// TrendService builds the trend report.
type TrendService struct {
	db       *database.TxManager
	clock    clock.Clock
	ledger   ledger.Ledger
	accounts wallet.Accounts
	goals    budget.Goals
	billing  billing.Entitlements
	zones    Timezones
}

// NewTrendService builds the service.
func NewTrendService(
	db *database.TxManager, clk clock.Clock, led ledger.Ledger, accounts wallet.Accounts,
	goals budget.Goals, bill billing.Entitlements, zones Timezones,
) *TrendService {
	return &TrendService{db: db, clock: clk, ledger: led, accounts: accounts, goals: goals, billing: bill, zones: zones}
}

// Trend returns income, expense, surplus, savings and unrecorded differences for the last
// `months` months, oldest first, ending with the current month in the user's timezone. Each
// month is computed with the same rules as the monthly report: as_of is its last day, or today
// for the current month. All reads share one consistent database snapshot.
func (s *TrendService) Trend(ctx context.Context, userID uuid.UUID, months int) ([]TrendMonth, error) {
	var out []TrendMonth
	err := s.db.WithReadSnapshot(ctx, func(ctx context.Context) error {
		premium, err := s.billing.IsPremium(ctx, userID)
		if err != nil {
			return fmt.Errorf("check premium: %w", err)
		}
		if !billing.AdvancedReportsAllowed(premium) {
			return ErrPremiumRequired
		}
		zone, err := s.zones.Timezone(ctx, userID)
		if err != nil {
			return fmt.Errorf("load timezone: %w", err)
		}
		today, err := domainrules.Today(s.clock.Now(), zone)
		if err != nil {
			return fmt.Errorf("compute today: %w", err)
		}
		accounts, err := s.accounts.ForRules(ctx, userID)
		if err != nil {
			return fmt.Errorf("load accounts: %w", err)
		}
		flows, err := s.ledger.Flows(ctx, userID, today)
		if err != nil {
			return fmt.Errorf("load flows: %w", err)
		}

		current := domainrules.MonthOf(today)
		out = make([]TrendMonth, 0, months)
		for i := months - 1; i >= 0; i-- {
			month := current.AddMonths(-i)
			asOf := asOfFor(month, today)
			goal, hasGoal, err := s.goals.EffectiveFor(ctx, userID, month)
			if err != nil {
				return fmt.Errorf("load budget goal: %w", err)
			}
			summary := domainrules.ComputeMonthlySummary(accounts, flows, month, asOf)
			budget := domainrules.ComputeBudget(accounts, flows, goal, hasGoal, month, asOf)

			var adjustments int64
			for _, f := range flows {
				if f.Type == domainrules.TxAdjustment && month.Contains(f.Date) && !f.Date.After(asOf) {
					adjustments += f.Amount
				}
			}
			out = append(out, TrendMonth{
				Month: month, Income: summary.Income, Expense: summary.Expense, Surplus: summary.Surplus,
				Savings: budget.Savings.Actual, Adjustments: adjustments,
			})
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}
