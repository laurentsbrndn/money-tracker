package billing

import (
	"context"
	"log/slog"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"moneytracker/internal/modules/billing/internal/client"
	"moneytracker/internal/modules/billing/internal/handler"
	"moneytracker/internal/modules/billing/internal/repository"
	"moneytracker/internal/modules/billing/internal/service"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// Deps are the dependencies of the billing module.
type Deps struct {
	DB    *database.TxManager
	Clock clock.Clock
	Log   *slog.Logger
	// RevenueCatAPIKey is the secret REST API key; empty disables the REST lookup, and the
	// webhook then works from the fields of each event only.
	RevenueCatAPIKey string
	// RevenueCatBaseURL overrides the REST origin; empty uses the real one.
	RevenueCatBaseURL string
	// PremiumEnded is called when a user's premium ends.
	PremiumEnded PremiumEndedHandler
}

// Module wires billing: the entitlement the whole backend asks about, and the RevenueCat
// webhook that is the only thing that changes it.
type Module struct {
	db           *database.TxManager
	entitlements *service.EntitlementService
	entHandler   *handler.EntitlementHandler
	hookHandler  *handler.WebhookHandler
	userData     *repository.UserDataRepository
}

// New builds the module.
func New(d Deps) *Module {
	ents := repository.NewEntitlementRepository(d.DB)
	subs := repository.NewSubscriptionRepository(d.DB)
	events := repository.NewBillingEventRepository(d.DB)
	entitlements := service.NewEntitlementService(ents, subs, d.Clock)
	rc := client.New(d.RevenueCatBaseURL, d.RevenueCatAPIKey)
	webhook := service.NewWebhookService(d.DB, d.Clock, events, ents, subs, rc, d.PremiumEnded, d.Log)
	return &Module{
		db:           d.DB,
		entitlements: entitlements,
		entHandler:   handler.NewEntitlementHandler(entitlements),
		hookHandler:  handler.NewWebhookHandler(webhook),
		userData:     repository.NewUserDataRepository(d.DB),
	}
}

// API returns the public interface of the module.
func (m *Module) API() Entitlements {
	return m.entitlements
}

// RegisterRoutes mounts GET /me/entitlements on the (guarded) /v1 group.
func (m *Module) RegisterRoutes(v1 fiber.Router) {
	v1.Get("/me/entitlements", m.entHandler.Get)
}

// RegisterWebhook mounts POST /billing/webhooks/revenuecat. Call it after the webhook secret
// guard has been installed on the path.
func (m *Module) RegisterWebhook(v1 fiber.Router) {
	v1.Post("/billing/webhooks/revenuecat", m.hookHandler.Receive)
}

// PurgeUser permanently deletes the user's entitlements, subscriptions and billing events in
// one transaction.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		return m.userData.DeleteByUser(ctx, userID)
	})
}
