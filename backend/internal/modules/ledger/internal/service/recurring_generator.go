package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
	"moneytracker/internal/platform/syncbase"
)

// Timezones tells the IANA timezone of a user (satisfied by ledger.Timezones).
type Timezones interface {
	Timezone(ctx context.Context, userID uuid.UUID) (string, error)
}

// recurringBatchSize bounds the users handled per run, like the maintenance job, so one run
// fits a serverless invocation. The rest is picked up by the next run.
const recurringBatchSize = 50

// RecurringResult counts what one run of the daily job did.
type RecurringResult struct {
	// Users is how many users were handled in this run (at most recurringBatchSize).
	Users   int
	Created int
	Paused  int
	Failed  int
	// HasMore is true when users were left for the next run.
	HasMore bool
}

// RecurringGenerator creates the transactions that recurring rules have come due for
// (docs/BUSINESS_RULES.md §5.2). The apps run the same logic when they open; the occurrence id
// is deterministic (UUIDv5 of rule id and date), so whoever runs first wins and the other
// finds the row and skips it (docs/SYNC_PROTOCOL.md S12).
type RecurringGenerator struct {
	db      *database.TxManager
	clock   clock.Clock
	rules   *repository.RecurringRuleRepository
	txs     *repository.TransactionRepository
	refs    references
	billing billing.Entitlements
	zones   Timezones
	log     *slog.Logger
}

// NewRecurringGenerator builds the generator.
func NewRecurringGenerator(
	db *database.TxManager, clk clock.Clock, rules *repository.RecurringRuleRepository,
	txs *repository.TransactionRepository, accounts wallet.Accounts, categories category.Categories, bill billing.Entitlements,
	zones Timezones, log *slog.Logger,
) *RecurringGenerator {
	return &RecurringGenerator{db: db, clock: clk, rules: rules, txs: txs, refs: references{accounts: accounts, categories: categories}, billing: bill, zones: zones, log: log}
}

// Run handles the users that have a rule due, at most recurringBatchSize per run, the most
// behind first (oldest due date, then user id). Each user is handled in its own transaction
// under the user's lock, so one failing user does not stop the others. A handled user has
// nothing due any more (last_generated_date moved on), so the next run continues with the next
// ones: no state of its own is needed, and creating an occurrence twice is impossible because
// its id is deterministic. The error joins the failures.
func (g *RecurringGenerator) Run(ctx context.Context) (RecurringResult, error) {
	schedules, err := g.rules.ActiveSchedules(ctx)
	if err != nil {
		return RecurringResult{}, err
	}
	queue := g.dueQueue(ctx, schedules, g.clock.Now())
	var res RecurringResult
	if len(queue) > recurringBatchSize {
		queue, res.HasMore = queue[:recurringBatchSize], true
	}
	var errs []error
	for _, userID := range queue {
		created, paused, err := g.runUser(ctx, userID)
		res.Users++
		res.Created += created
		res.Paused += paused
		if err != nil {
			res.Failed++
			g.log.ErrorContext(ctx, "recurring: user failed", "user_id", userID, "error", err)
			errs = append(errs, fmt.Errorf("user %s: %w", userID, err))
		}
	}
	return res, errors.Join(errs...)
}

// dueQueue lists the users with a rule that is due, most behind first. Candidates come from
// the schedules alone: a rule counts when an occurrence falls on or before the UTC date plus one
// day (the furthest any timezone is ahead). Each candidate's timezone then gives the exact
// "today", so a user whose next occurrence is only tomorrow does not stay in the queue (that
// would hold a place in every run). The queue is built from reads only; nothing is locked.
func (g *RecurringGenerator) dueQueue(ctx context.Context, rules []model.RecurringRule, now time.Time) []uuid.UUID {
	horizon := civil.FromTime(now.UTC()).AddDays(1)
	byUser := map[uuid.UUID][]*model.RecurringRule{}
	for i := range rules {
		if len(occurrencesOf(&rules[i], horizon)) > 0 {
			byUser[rules[i].UserID] = append(byUser[rules[i].UserID], &rules[i])
		}
	}

	earliest := map[uuid.UUID]civil.Date{}
	for userID, userRules := range byUser {
		today := horizon
		if zone, err := g.zones.Timezone(ctx, userID); err == nil {
			if t, err := domainrules.Today(now, zone); err == nil {
				today = t
			}
		}
		// An unreadable timezone keeps the user with the loose horizon: handling the user
		// reports the real error.
		for _, r := range userRules {
			if due := occurrencesOf(r, today); len(due) > 0 {
				if cur, ok := earliest[userID]; !ok || due[0].Before(cur) {
					earliest[userID] = due[0]
				}
			}
		}
	}
	users := make([]uuid.UUID, 0, len(earliest))
	for id := range earliest {
		users = append(users, id)
	}
	sort.Slice(users, func(a, b int) bool {
		da, db := earliest[users[a]], earliest[users[b]]
		if c := da.Compare(db); c != 0 {
			return c < 0
		}
		return users[a].String() < users[b].String()
	})
	return users
}

// occurrencesOf lists the dates a rule is due for on or before today.
func occurrencesOf(r *model.RecurringRule, today civil.Date) []civil.Date {
	var last civil.Date
	if r.LastGeneratedDate != nil {
		last = *r.LastGeneratedDate
	}
	return domainrules.Occurrences(toRecurrenceRule(r), last, today)
}

// runUser generates the due transactions of one user. A user who is no longer premium has their
// rules paused instead: a safety net for an EXPIRATION webhook that never arrived.
func (g *RecurringGenerator) runUser(ctx context.Context, userID uuid.UUID) (created, paused int, err error) {
	err = g.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, g.db.DB(ctx), userID); err != nil {
			return err
		}
		now := g.clock.Now()
		premium, err := g.billing.IsPremium(ctx, userID)
		if err != nil {
			return err
		}
		if !premium {
			paused, err = g.rules.PauseActive(ctx, userID, now)
			return err
		}
		zone, err := g.zones.Timezone(ctx, userID)
		if err != nil {
			return fmt.Errorf("load timezone: %w", err)
		}
		today, err := domainrules.Today(now, zone)
		if err != nil {
			return fmt.Errorf("compute today: %w", err)
		}
		rules, err := g.rules.ListActive(ctx, userID)
		if err != nil {
			return err
		}
		for i := range rules {
			n, err := g.generate(ctx, userID, &rules[i], today)
			if err != nil {
				return err
			}
			created += n
		}
		return nil
	})
	return created, paused, err
}

// generate creates the due occurrences of one rule and moves its last_generated_date.
func (g *RecurringGenerator) generate(ctx context.Context, userID uuid.UUID, rule *model.RecurringRule, today civil.Date) (int, error) {
	var last civil.Date
	if rule.LastGeneratedDate != nil {
		last = *rule.LastGeneratedDate
	}
	due := domainrules.Occurrences(toRecurrenceRule(rule), last, today)
	if len(due) == 0 {
		return 0, nil
	}

	opening, ok, err := g.openingDate(ctx, userID, rule)
	if err != nil {
		return 0, err
	}
	if !ok {
		// Nothing can be recorded for a rule whose account or category is gone. Moving
		// last_generated_date on keeps it from being due forever (and from holding a place
		// at the front of every run).
		g.log.WarnContext(ctx, "recurring: rule has no account or category any more, skipping its due dates", "rule_id", rule.ID)
		lastDue := due[len(due)-1]
		rule.LastGeneratedDate = &lastDue
		rule.UpdatedAt = syncbase.NewTime(g.clock.Now())
		return 0, g.rules.Save(ctx, rule, g.clock.Now())
	}

	now := g.clock.Now()
	status := model.StatusPosted
	if rule.Mode == model.ModeConfirm {
		status = model.StatusPendingConfirmation
	}
	var rows []*model.Transaction
	for _, date := range due {
		if date.Before(opening) {
			continue // before an account existed: nothing to record
		}
		id := idgen.RecurringOccurrenceID(rule.ID, date)
		// A row with this id counts even when it was deleted: the user removed it on purpose.
		existing, err := g.txs.FindAnyUser(ctx, id)
		if err != nil {
			return 0, err
		}
		if existing != nil {
			continue
		}
		ruleID := rule.ID
		rows = append(rows, &model.Transaction{
			Columns: syncbase.Columns{
				ID: id, UserID: userID, CreatedAt: syncbase.NewTime(now), UpdatedAt: syncbase.NewTime(now),
			},
			Type: rule.Type, Status: status, TransactionDate: date, Amount: rule.Amount,
			Currency: currencyIDR, AccountID: rule.AccountID, ToAccountID: rule.ToAccountID,
			CategoryID: rule.CategoryID, Allocation: rule.Allocation, Source: rule.Source,
			Note: rule.Note, RecurringRuleID: &ruleID,
		})
	}
	if err := g.txs.SaveMany(ctx, rows, now); err != nil {
		return 0, err
	}

	lastDue := due[len(due)-1]
	rule.LastGeneratedDate = &lastDue
	rule.UpdatedAt = syncbase.NewTime(now)
	if err := g.rules.Save(ctx, rule, now); err != nil {
		return 0, err
	}
	return len(rows), nil
}

// openingDate returns the latest opening date among the template's accounts; ok is false when
// an account is missing or deleted, or the category is gone.
func (g *RecurringGenerator) openingDate(ctx context.Context, userID uuid.UUID, rule *model.RecurringRule) (civil.Date, bool, error) {
	ids := []uuid.UUID{rule.AccountID}
	if rule.ToAccountID != nil {
		ids = append(ids, *rule.ToAccountID)
	}
	var opening civil.Date
	for _, id := range ids {
		acc, err := g.refs.accounts.Get(ctx, userID, id)
		if err != nil {
			if isNotFound(err) {
				return civil.Date{}, false, nil
			}
			return civil.Date{}, false, err
		}
		if acc.IsDeleted {
			return civil.Date{}, false, nil
		}
		if opening.IsZero() || acc.OpeningDate.After(opening) {
			opening = acc.OpeningDate
		}
	}
	if rule.CategoryID != nil {
		cat, err := g.refs.categories.Get(ctx, userID, *rule.CategoryID)
		if err != nil {
			if isCategoryNotFound(err) {
				return civil.Date{}, false, nil
			}
			return civil.Date{}, false, err
		}
		if cat.IsDeleted {
			return civil.Date{}, false, nil
		}
	}
	return opening, true, nil
}

// toRecurrenceRule converts a stored rule into the pure schedule of domainrules.
func toRecurrenceRule(r *model.RecurringRule) domainrules.RecurrenceRule {
	rule := domainrules.RecurrenceRule{
		Frequency:     domainrules.RecurringFrequency(r.Frequency),
		IntervalCount: int(r.IntervalCount),
		StartDate:     r.StartDate,
	}
	if r.DayOfWeek != nil {
		rule.DayOfWeek = int(*r.DayOfWeek)
	}
	if r.DayOfMonth != nil {
		rule.DayOfMonth = int(*r.DayOfMonth)
	}
	if r.MonthOfYear != nil {
		rule.MonthOfYear = int(*r.MonthOfYear)
	}
	if r.EndDate != nil {
		rule.EndDate = *r.EndDate
	}
	return rule
}
