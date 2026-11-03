package database

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// Pool settings are small because the backend runs serverless.
const (
	maxOpenConns    = 5
	maxIdleConns    = 2
	connMaxIdleTime = 30 * time.Second
	connMaxLifetime = 5 * time.Minute
)

// Open connects to PostgreSQL through GORM.
//
// PreferSimpleProtocol keeps the connection safe behind PgBouncer in transaction mode (Neon pooled).
func Open(dsn string, log *slog.Logger) (*gorm.DB, error) {
	db, err := gorm.Open(
		postgres.New(postgres.Config{DSN: dsn, PreferSimpleProtocol: true}),
		&gorm.Config{
			PrepareStmt:            false,
			SkipDefaultTransaction: true,
			// Unique violations surface as gorm.ErrDuplicatedKey, so services can map them
			// to domain errors without importing the driver.
			TranslateError: true,
			// Do not ping on open: the server must start even when the database is down so that
			// /healthz can report 503. A malformed DSN still fails here.
			DisableAutomaticPing: true,
			Logger:               newGormLogger(log),
		},
	)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, fmt.Errorf("get sql.DB: %w", err)
	}
	sqlDB.SetMaxOpenConns(maxOpenConns)
	sqlDB.SetMaxIdleConns(maxIdleConns)
	sqlDB.SetConnMaxIdleTime(connMaxIdleTime)
	sqlDB.SetConnMaxLifetime(connMaxLifetime)
	return db, nil
}

// Ping checks that the database is reachable.
func Ping(ctx context.Context, db *gorm.DB) error {
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("get sql.DB: %w", err)
	}
	if err := sqlDB.PingContext(ctx); err != nil {
		return fmt.Errorf("ping database: %w", err)
	}
	return nil
}

// Close releases the connection pool.
func Close(db *gorm.DB) error {
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("get sql.DB: %w", err)
	}
	if err := sqlDB.Close(); err != nil {
		return fmt.Errorf("close database: %w", err)
	}
	return nil
}
