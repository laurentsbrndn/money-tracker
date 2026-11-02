// Command migrate runs database migrations against DATABASE_URL_DIRECT (the Neon direct
// connection, not the pooled one).
//
// Usage: go run ./cmd/migrate up|down|status
package main

import (
	"errors"
	"fmt"
	"log/slog"
	"os"

	"github.com/go-gormigrate/gormigrate/v2"
	"gorm.io/gorm"

	"moneytracker/internal/platform/config"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/logger"
	"moneytracker/migrations"
)

const usage = "usage: migrate up|down|status"

func main() {
	if err := run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "migrate:", err)
		os.Exit(1)
	}
}

func run(args []string) error {
	if len(args) != 1 {
		return errors.New(usage)
	}
	command := args[0]
	if command != "up" && command != "down" && command != "status" {
		return fmt.Errorf("unknown command %q; %s", command, usage)
	}

	cfg, err := config.LoadMigrate()
	if err != nil {
		return err
	}
	log := logger.New(cfg.LogLevel)

	db, err := database.Open(cfg.DatabaseURLDirect, log)
	if err != nil {
		return err
	}
	defer closeDB(db, log)

	// PostgreSQL DDL is transactional, so a failed migration leaves nothing half-applied.
	opts := *gormigrate.DefaultOptions
	opts.UseTransaction = true
	m := gormigrate.New(db, &opts, migrations.All())

	switch command {
	case "up":
		if err := m.Migrate(); err != nil {
			return fmt.Errorf("migrate up: %w", err)
		}
		fmt.Println("migrations are up to date")
	case "down":
		if err := m.RollbackLast(); err != nil {
			return fmt.Errorf("migrate down: %w", err)
		}
		fmt.Println("rolled back the last migration")
	case "status":
		return printStatus(db)
	}
	return nil
}

// printStatus lists every known migration as applied or pending.
func printStatus(db *gorm.DB) error {
	applied := map[string]bool{}
	if db.Migrator().HasTable(gormigrate.DefaultOptions.TableName) {
		var ids []string
		err := db.Table(gormigrate.DefaultOptions.TableName).Pluck(gormigrate.DefaultOptions.IDColumnName, &ids).Error
		if err != nil {
			return fmt.Errorf("read applied migrations: %w", err)
		}
		for _, id := range ids {
			applied[id] = true
		}
	}

	for _, mig := range migrations.All() {
		state := "pending"
		if applied[mig.ID] {
			state = "applied"
		}
		fmt.Printf("%-8s %s\n", state, mig.ID)
	}
	return nil
}

func closeDB(db *gorm.DB, log *slog.Logger) {
	if err := database.Close(db); err != nil {
		log.Error("close database", "error", err)
	}
}
