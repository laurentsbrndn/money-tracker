package ledger

import (
	"context"
	"log/slog"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/ledger/internal/handler"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/modules/ledger/internal/synchandler"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/civil"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the ledger module.
type Deps struct {
	DB        *database.TxManager
	Clock     clock.Clock
	Log       *slog.Logger
	Wallet    wallet.Accounts
	Category  category.Categories
	Billing   billing.Entitlements
	Timezones Timezones
}

// Module wires the ledger module.
type Module struct {
	db           *database.TxManager
	clock        clock.Clock
	transactions *service.TransactionService
	rules        *service.RecurringRuleService
	aggregates   *service.AggregateService
	accountRefs  *service.AccountReferences
	categoryRefs *service.CategoryReferences
	cron         *handler.CronRecurringHandler
	syncs        []syncbase.Handler
}

// New builds the module.
func New(d Deps) *Module {
	repo := repository.NewTransactionRepository(d.DB)
	ruleRepo := repository.NewRecurringRuleRepository(d.DB)
	svc := service.NewTransactionService(repo, d.Wallet, d.Category, d.Clock)
	rules := service.NewRecurringRuleService(ruleRepo, d.Wallet, d.Category, d.Billing, d.Clock)
	gen := service.NewRecurringGenerator(d.DB, d.Clock, ruleRepo, repo, d.Wallet, d.Category, d.Billing, d.Timezones, d.Log)
	return &Module{
		db:           d.DB,
		clock:        d.Clock,
		transactions: svc,
		rules:        rules,
		aggregates:   service.NewAggregateService(repo),
		accountRefs:  service.NewAccountReferences(repo),
		categoryRefs: service.NewCategoryReferences(repo),
		cron:         handler.NewCronRecurringHandler(gen, d.Log),
		syncs: []syncbase.Handler{
			synchandler.NewTransactionHandler(repo, svc),
			synchandler.NewRecurringRuleHandler(ruleRepo, rules),
		},
	}
}

// API returns the public interface of the module.
func (m *Module) API() Ledger {
	return m
}

// Aggregates implements Ledger.
func (m *Module) Aggregates(ctx context.Context, userID uuid.UUID, q AggregateQuery) (AggregateResult, error) {
	return m.aggregates.Aggregates(ctx, userID, q)
}

// Flows implements Ledger.
func (m *Module) Flows(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]domainrules.Transaction, error) {
	return m.aggregates.Flows(ctx, userID, asOf)
}

// PauseRules implements Ledger.
func (m *Module) PauseRules(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		_, err := m.rules.PauseActive(ctx, userID, m.clock.Now())
		return err
	})
}

// AccountReferences implements Ledger.
func (m *Module) AccountReferences() wallet.ReferenceChecker {
	return m.accountRefs
}

// CategoryReferences implements Ledger.
func (m *Module) CategoryReferences() category.ReferenceChecker {
	return m.categoryRefs
}

// RegisterRoutes mounts the cron job on the router of /v1/internal/cron, after its guard.
func (m *Module) RegisterRoutes(cron fiber.Router) {
	cron.Get("/recurring", m.cron.Run)
}

// RegisterSyncHandlers registers the transactions and recurring_rules sync handlers.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	for _, h := range m.syncs {
		r.Register(h)
	}
}

// PurgeUser permanently deletes the user's transactions and recurring rules under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		if err := m.transactions.PurgeUser(ctx, userID); err != nil {
			return err
		}
		return m.rules.PurgeUser(ctx, userID)
	})
}
