package report

import (
	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/budget"
	"moneytracker/internal/modules/ledger"
	"moneytracker/internal/modules/report/internal/handler"
	"moneytracker/internal/modules/report/internal/service"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// Deps are the dependencies of the report module.
type Deps struct {
	DB        *database.TxManager
	Clock     clock.Clock
	Ledger    ledger.Ledger
	Accounts  wallet.Accounts
	Snapshots wallet.Snapshots
	Goals     budget.Goals
	Billing   billing.Entitlements
	Timezones Timezones
}

// Module wires the report module.
type Module struct {
	handler *handler.ReportHandler
}

// New builds the module.
func New(d Deps) *Module {
	monthly := service.NewMonthlyReportService(d.DB, d.Clock, d.Ledger, d.Accounts, d.Snapshots, d.Goals, d.Billing, d.Timezones)
	trend := service.NewTrendService(d.DB, d.Clock, d.Ledger, d.Accounts, d.Goals, d.Billing, d.Timezones)
	return &Module{handler: handler.NewReportHandler(monthly, trend)}
}

// RegisterRoutes mounts GET /reports/monthly and /reports/trend on the (guarded) /v1 group.
func (m *Module) RegisterRoutes(v1 fiber.Router) {
	v1.Get("/reports/monthly", m.handler.Monthly)
	v1.Get("/reports/trend", m.handler.Trend)
}
