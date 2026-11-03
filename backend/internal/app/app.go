// Package app is the composition root: it builds every dependency and wires them together.
// Modules are added here as they are implemented (docs/ARCHITECTURE.md §3.2).
package app

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/gofiber/fiber/v3"
	"gorm.io/gorm"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/budget"
	"moneytracker/internal/modules/category"
	"moneytracker/internal/modules/identity"
	"moneytracker/internal/modules/ledger"
	syncmod "moneytracker/internal/modules/sync"
	"moneytracker/internal/modules/wallet"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/config"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/httpx"
)

const (
	bodyLimit    = 1 << 20 // 1 MB
	readTimeout  = 10 * time.Second
	writeTimeout = 15 * time.Second
)

// ipHeader is the proxy header c.IP() reads outside local. Vercel documents that it
// overwrites X-Forwarded-For and does not forward external values (anti-spoofing); it makes
// no such statement for X-Real-IP or X-Vercel-Forwarded-For.
const ipHeader = fiber.HeaderXForwardedFor

// App is the assembled HTTP application.
type App struct {
	cfg    config.Config
	log    *slog.Logger
	db     *gorm.DB
	web    *fiber.App
	cancel context.CancelFunc // ends background work (JWKS refresh)

	identity *identity.Module
	sync     *syncmod.Module
	// purgers delete a user's data permanently; the maintenance job calls them.
	purgers []identity.UserPurger
}

// fiberConfig builds the Fiber settings. Behind Vercel the client IP is read from
// X-Forwarded-For, which only a trusted proxy may set. Vercel does not publish its proxy
// addresses and the function is reachable only through Vercel, so every peer is trusted in
// preview and production. Locally the header is ignored and c.IP() is the TCP peer.
func fiberConfig(cfg config.Config, log *slog.Logger) fiber.Config {
	fc := fiber.Config{
		BodyLimit:    bodyLimit,
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
		ErrorHandler: httpx.ErrorHandler(log),
	}
	if cfg.AppEnv != config.EnvLocal {
		fc.ProxyHeader = ipHeader
		fc.TrustProxy = true
		fc.TrustProxyConfig = fiber.TrustProxyConfig{Proxies: []string{"0.0.0.0/0", "::/0"}}
		fc.EnableIPValidation = true
	}
	return fc
}

// Build creates the database handle, the Fiber app, the global middleware and the routes.
func Build(cfg config.Config, log *slog.Logger) (*App, error) {
	// Integration config is checked before anything is opened.
	mail, err := buildMailer(cfg, log)
	if err != nil {
		return nil, err
	}
	base, cancel := context.WithCancel(context.Background())
	appleVerifier, googleVerifier, err := buildVerifiers(base, cfg, log)
	if err != nil {
		cancel()
		return nil, err
	}

	db, err := database.Open(cfg.DatabaseURL, log)
	if err != nil {
		cancel()
		return nil, err
	}

	clk := clock.NewSystem()
	txm := database.NewTxManager(db)
	jwt := auth.NewJWT(cfg.JWTSecret, cfg.JWTIssuer, cfg.AccessTokenTTL, clk)

	billingModule := billing.New()

	// ledger implements the reference checkers that wallet and category consume while ledger
	// itself needs wallet and category: bind them once ledger exists (see lateReferences).
	refs := &lateReferences{}
	categoryModule := category.New(category.Deps{
		DB: txm, Clock: clk, Billing: billingModule.API(), References: refs.categoryChecker(),
	})
	walletModule := wallet.New(wallet.Deps{
		DB: txm, Clock: clk, Billing: billingModule.API(), References: refs.accountChecker(),
	})
	ledgerModule := ledger.New(ledger.Deps{
		DB: txm, Clock: clk, Wallet: walletModule.API(), Category: categoryModule.API(),
	})
	refs.bind(ledgerModule.AccountReferences(), ledgerModule.CategoryReferences())
	budgetModule := budget.New(budget.Deps{DB: txm, Clock: clk})

	seed := &onboarder{
		categories: categoryModule.API(),
		accounts:   walletModule.API(),
		goals:      budgetModule.API(),
		clock:      clk,
	}
	identityModule := identity.New(identity.Deps{
		DB:              txm,
		Clock:           clk,
		JWT:             jwt,
		OTP:             auth.NewOTP(cfg.OTPSecret),
		Mailer:          mail,
		Onboarder:       seed,
		Entitlements:    entitlementReader{billing: billingModule.API()},
		AppleVerifier:   appleVerifier,
		GoogleVerifier:  googleVerifier,
		RefreshTokenTTL: cfg.RefreshTokenTTL,
		Log:             log,
	})
	seed.settings = identityModule.Settings()

	// Every module registers its entity handlers before the sync module is built.
	registry := syncmod.NewRegistry()
	identityModule.RegisterSyncHandlers(registry)
	categoryModule.RegisterSyncHandlers(registry)
	walletModule.RegisterSyncHandlers(registry)
	ledgerModule.RegisterSyncHandlers(registry)
	budgetModule.RegisterSyncHandlers(registry)
	syncModule := syncmod.New(syncmod.Deps{DB: txm, Clock: clk, Billing: billingModule.API(), Registry: registry})

	a := &App{
		cfg: cfg, log: log, db: db,
		web:      fiber.New(fiberConfig(cfg, log)),
		cancel:   cancel,
		identity: identityModule,
		sync:     syncModule,
		// Children before parents; identity (the users row) goes last.
		purgers: []identity.UserPurger{
			ledgerModule, budgetModule, walletModule, categoryModule, syncModule, identityModule, billingModule,
		},
	}
	a.registerRoutes(jwt)
	return a, nil
}

// Run serves HTTP on the configured port until ctx is cancelled, then shuts down gracefully.
func (a *App) Run(ctx context.Context) error {
	err := a.web.Listen(":"+a.cfg.Port, fiber.ListenConfig{
		DisableStartupMessage: true,
		GracefulContext:       ctx,
	})
	if err != nil {
		return fmt.Errorf("serve http: %w", err)
	}
	return nil
}

// Close stops background work and releases the database pool.
func (a *App) Close() error {
	a.cancel()
	return database.Close(a.db)
}
