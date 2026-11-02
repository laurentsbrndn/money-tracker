package config

import (
	"fmt"
	"strings"

	"github.com/caarlos0/env/v11"
)

// MigrateConfig is the minimal configuration for cmd/migrate.
type MigrateConfig struct {
	DatabaseURLDirect string `env:"DATABASE_URL_DIRECT,required"`
	LogLevel          string `env:"LOG_LEVEL" envDefault:"info"`
}

// LoadMigrate reads only what cmd/migrate needs (Neon direct connection).
func LoadMigrate() (MigrateConfig, error) {
	loadDotEnv()

	var cfg MigrateConfig
	if err := env.Parse(&cfg); err != nil {
		return MigrateConfig{}, fmt.Errorf("read environment: %w", err)
	}
	if strings.TrimSpace(cfg.DatabaseURLDirect) == "" {
		return MigrateConfig{}, fmt.Errorf("invalid configuration: DATABASE_URL_DIRECT must not be empty")
	}
	return cfg, nil
}
