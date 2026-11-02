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

// App is the assembled HTTP application.
type App struct {
	cfg config.Config
	log *slog.Logger
	db  *gorm.DB
	web *fiber.App
}

// Build creates the database handle, the Fiber app, the global middleware and the routes.
func Build(cfg config.Config, log *slog.Logger) (*App, error) {
	db, err := database.Open(cfg.DatabaseURL, log)
	if err != nil {
		return nil, err
	}

	web := fiber.New(fiber.Config{
		BodyLimit:    bodyLimit,
		ReadTimeout:  readTimeout,
		WriteTimeout: writeTimeout,
		ErrorHandler: httpx.ErrorHandler(log),
	})

	a := &App{cfg: cfg, log: log, db: db, web: web}
	jwt := auth.NewJWT(cfg.JWTSecret, cfg.JWTIssuer, cfg.AccessTokenTTL, clock.NewSystem())
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

// Close releases the database pool.
func (a *App) Close() error {
	return database.Close(a.db)
}
