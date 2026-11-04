package app

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/httpx"
	"moneytracker/internal/platform/middleware"
)

const healthTimeout = 2 * time.Second

// Prefixes (lower case) of /v1 routes that are not called by the apps: they skip client_info
// and, with /v1/auth/, the global auth guard (docs/BACKEND.md §4.4).
const (
	cronPrefix    = "/v1/internal/cron"
	webhookPrefix = "/v1/billing/webhooks"
	authPrefix    = "/v1/auth/"
)

type healthResponse struct {
	Status string `json:"status"`
}

// registerRoutes sets the global middleware order (request_id → security_headers → recover → access_log), the
// health check, and the /v1 guards. Modules add their routes here as they are implemented.
func (a *App) registerRoutes(jwt middleware.AccessTokenVerifier) {
	a.web.Use(middleware.RequestID())
	a.web.Use(middleware.SecurityHeaders())
	a.web.Use(middleware.Recover(a.log))
	a.web.Use(middleware.AccessLog(a.log))

	a.web.Get("/healthz", a.health)

	// Apps: client_info → auth. Every guard skips the routes below that use their own secret.
	clientInfo := middleware.ClientInfo(a.cfg.MinAppVersionAndroid, a.cfg.MinAppVersionIOS)
	authGuard := middleware.Auth(jwt)
	a.web.Use("/v1", skipFor(clientInfo, cronPrefix, webhookPrefix))
	a.web.Use("/v1", skipFor(authGuard, cronPrefix, webhookPrefix, authPrefix))

	// Module routes. /v1/auth has no global guard; the identity routes that need a user carry
	// authGuard themselves.
	v1 := a.web.Group("/v1")
	a.identity.RegisterRoutes(v1.Group("/auth"), v1, authGuard)
	a.sync.RegisterRoutes(v1)
	a.report.RegisterRoutes(v1)
	a.billing.RegisterRoutes(v1)

	// Vercel Cron and RevenueCat: shared-secret Bearer, no client headers.
	a.web.Use(cronPrefix, middleware.CronAuth(a.cfg.CronSecret))
	a.web.Use(webhookPrefix, middleware.WebhookAuth(a.cfg.RevenueCat.WebhookSecret))

	// RevenueCat webhook and cron jobs. Register them after the guards above (Fiber runs
	// handlers in registration order).
	a.billing.RegisterWebhook(v1)
	a.ledger.RegisterRoutes(a.web.Group(cronPrefix))
	a.web.Get(cronPrefix+"/maintenance", a.maintenance.Handle)
}

// health reports whether the database answers within healthTimeout. The response never
// carries error details; they go to the log only.
func (a *App) health(c fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(c.Context(), healthTimeout)
	defer cancel()

	if err := database.Ping(ctx, a.db); err != nil {
		a.log.WarnContext(ctx, "health check failed", "request_id", httpx.RequestID(c), "error", err)
		return c.Status(http.StatusServiceUnavailable).JSON(healthResponse{Status: "unavailable"})
	}
	return httpx.OK(c, healthResponse{Status: "ok"})
}

// skipFor runs next except for paths under one of the given prefixes. Matching is
// case-insensitive, like Fiber's router.
func skipFor(next fiber.Handler, prefixes ...string) fiber.Handler {
	return func(c fiber.Ctx) error {
		path := strings.ToLower(c.Path())
		for _, prefix := range prefixes {
			if strings.HasPrefix(path, prefix) {
				return c.Next()
			}
		}
		return next(c)
	}
}
