// Command api is the Vercel entrypoint: load config, build the app, serve on PORT.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"moneytracker/internal/app"
	"moneytracker/internal/platform/config"
	"moneytracker/internal/platform/logger"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "api:", err)
		os.Exit(1)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}
	log := logger.New(cfg.LogLevel)
	slog.SetDefault(log)

	application, err := app.Build(cfg, log)
	if err != nil {
		return err
	}
	defer func() {
		if err := application.Close(); err != nil {
			log.Error("close application", "error", err)
		}
	}()

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	log.Info("server starting", "env", cfg.AppEnv, "port", cfg.Port)
	return application.Run(ctx)
}
