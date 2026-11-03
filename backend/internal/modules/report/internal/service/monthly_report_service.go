// Package service holds the report logic: it reads through the public interfaces of other
// modules and computes every figure with domainrules.
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
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// ErrHistoryLimit is returned when a free user asks for a month older than the plan allows
// (docs/BUSINESS_RULES.md §7).
var ErrHistoryLimit = errors.New("month is outside the free history limit")

// Timezones tells the IANA timezone of a user (satisfied by report.Timezones).
type Timezones interface {
	Timezone(ctx context.Context, userID uuid.UUID) (string, error)
}

// MonthlyReport is the report of one month, computed with domainrules.
type MonthlyReport struct {
	Summary           domainrules.MonthlySummary
	Reconciliation    domainrules.Reconciliation
	Budget            domainrules.Budget
	ExpenseByCategory []ledger.CategoryTotal
	IncomeByCategory  []ledger.CategoryTotal
}

// MonthlyReportService builds the monthly report.
type MonthlyReportService struct {
	db        *database.TxManager
	clock     clock.Clock
	ledger    ledger.Ledger
	accounts  wallet.Accounts
	snapshots wallet.Snapshots
	goals     budget.Goals
	billing   billing.Entitlements
	zones     Timezones
}

// NewMonthlyReportService builds the service.
func NewMonthlyReportService(
	db *database.TxManager,
	clk clock.Clock,
	led ledger.Ledger,
	accounts wallet.Accounts,
	snapshots wallet.Snapshots,
	goals budget.Goals,
	bill billing.Entitlements,
	zones Timezones,
) *MonthlyReportService {
	return &MonthlyReportService{
		db: db, clock: clk, ledger: led, accounts: accounts, snapshots: snapshots,
		goals: goals, billing: bill, zones: zones,
	}
}

// Monthly builds the report of month for the user.
//
// The reference date (as_of) is the last day of the month, or today in the user's timezone when
// the month is not over yet: later transactions do not count (docs/BUSINESS_RULES.md §3). Free
// users may view the current month and the two before it. All reads share one consistent
// database snapshot.
func (s *MonthlyReportService) Monthly(ctx context.Context, userID uuid.UUID, month domainrules.YearMonth) (MonthlyReport, error) {
	var report MonthlyReport
	err := s.db.WithReadSnapshot(ctx, func(ctx context.Context) error {
		premium, err := s.billing.IsPremium(ctx, userID)
		if err != nil {
			return fmt.Errorf("check premium: %w", err)
		}
		zone, err := s.zones.Timezone(ctx, userID)
		if err != nil {
			return fmt.Errorf("load timezone: %w", err)
		}
		today, err := domainrules.Today(s.clock.Now(), zone)
		if err != nil {
			return fmt.Errorf("compute today: %w", err)
		}
		if !billing.HistoryMonthAllowed(premium, month, domainrules.MonthOf(today)) {
			return ErrHistoryLimit
		}
		asOf := asOfFor(month, today)

		accounts, err := s.accounts.ForRules(ctx, userID)
		if err != nil {
			return fmt.Errorf("load accounts: %w", err)
		}
		snapshots, err := s.snapshots.Latest(ctx, userID, asOf)
		if err != nil {
			return fmt.Errorf("load snapshots: %w", err)
		}
		goal, hasGoal, err := s.goals.EffectiveFor(ctx, userID, month)
		if err != nil {
			return fmt.Errorf("load budget goal: %w", err)
		}
		agg, err := s.ledger.Aggregates(ctx, userID, ledger.AggregateQuery{AsOf: asOf, Month: month})
		if err != nil {
			return fmt.Errorf("load aggregates: %w", err)
		}

		report = MonthlyReport{
			Summary:           domainrules.ComputeMonthlySummary(accounts, agg.Flows, month, asOf),
			Reconciliation:    domainrules.Reconcile(accounts, agg.Flows, snapshots, asOf),
			Budget:            domainrules.ComputeBudget(accounts, agg.Flows, goal, hasGoal, month, asOf),
			ExpenseByCategory: agg.ExpenseByCategory,
			IncomeByCategory:  agg.IncomeByCategory,
		}
		return nil
	})
	if err != nil {
		return MonthlyReport{}, err
	}
	return report, nil
}

// asOfFor is the last day of the month, capped at today.
func asOfFor(month domainrules.YearMonth, today civil.Date) civil.Date {
	if last := month.Last(); last.Before(today) {
		return last
	}
	return today
}
