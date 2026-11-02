package config

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/caarlos0/env/v11"
	"github.com/joho/godotenv"
)

const (
	EnvLocal      = "local"
	EnvPreview    = "preview"
	EnvProduction = "production"
)

var semverPattern = regexp.MustCompile(`^\d+\.\d+\.\d+$`)

// Config holds all environment configuration.
//
// Core fields are validated by Load. Integration groups (Apple, Google, Email, RevenueCat)
// are parsed but not validated at start; call their Validate method when the module that
// uses them is wired in the composition root.
type Config struct {
	AppEnv               string        `env:"APP_ENV,required"`
	Port                 string        `env:"PORT" envDefault:"8080"`
	DatabaseURL          string        `env:"DATABASE_URL,required"`
	JWTSecret            string        `env:"JWT_SECRET,required"`
	JWTIssuer            string        `env:"JWT_ISSUER,required"`
	AccessTokenTTL       time.Duration `env:"ACCESS_TOKEN_TTL" envDefault:"15m"`
	RefreshTokenTTL      time.Duration `env:"REFRESH_TOKEN_TTL" envDefault:"1440h"`
	OTPSecret            string        `env:"OTP_SECRET,required"`
	CronSecret           string        `env:"CRON_SECRET,required"`
	MinAppVersionAndroid string        `env:"MIN_APP_VERSION_ANDROID" envDefault:"0.0.0"`
	MinAppVersionIOS     string        `env:"MIN_APP_VERSION_IOS" envDefault:"0.0.0"`
	LogLevel             string        `env:"LOG_LEVEL" envDefault:"info"`

	Apple      AppleConfig
	Google     GoogleConfig
	Email      EmailConfig
	RevenueCat RevenueCatConfig
}

// IsProduction reports whether the app runs in the production environment.
func (c Config) IsProduction() bool {
	return c.AppEnv == EnvProduction
}

// Load reads the environment (and .env when running locally), then validates the core fields.
func Load() (Config, error) {
	loadDotEnv()

	var cfg Config
	if err := env.Parse(&cfg); err != nil {
		return Config{}, fmt.Errorf("read environment: %w", err)
	}
	if err := cfg.validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) validate() error {
	var errs []error
	add := func(format string, args ...any) {
		errs = append(errs, fmt.Errorf(format, args...))
	}

	switch c.AppEnv {
	case EnvLocal, EnvPreview, EnvProduction:
	default:
		add("APP_ENV must be one of local, preview, production (got %q)", c.AppEnv)
	}
	if strings.TrimSpace(c.Port) == "" {
		add("PORT must not be empty")
	}
	if strings.TrimSpace(c.DatabaseURL) == "" {
		add("DATABASE_URL must not be empty")
	}
	if len(c.JWTSecret) < 32 {
		add("JWT_SECRET must be at least 32 bytes")
	}
	if strings.TrimSpace(c.JWTIssuer) == "" {
		add("JWT_ISSUER must not be empty")
	}
	if len(c.OTPSecret) < 32 {
		add("OTP_SECRET must be at least 32 bytes")
	}
	if len(c.CronSecret) < 16 {
		add("CRON_SECRET must be at least 16 characters")
	}
	if c.AccessTokenTTL <= 0 {
		add("ACCESS_TOKEN_TTL must be positive")
	}
	if c.RefreshTokenTTL <= 0 {
		add("REFRESH_TOKEN_TTL must be positive")
	}
	if !semverPattern.MatchString(c.MinAppVersionAndroid) {
		add("MIN_APP_VERSION_ANDROID must be MAJOR.MINOR.PATCH (got %q)", c.MinAppVersionAndroid)
	}
	if !semverPattern.MatchString(c.MinAppVersionIOS) {
		add("MIN_APP_VERSION_IOS must be MAJOR.MINOR.PATCH (got %q)", c.MinAppVersionIOS)
	}

	if err := errors.Join(errs...); err != nil {
		return fmt.Errorf("invalid configuration: %w", err)
	}
	return nil
}

// loadDotEnv loads .env for local development only. A missing file is not an error.
func loadDotEnv() {
	if e := os.Getenv("APP_ENV"); e == "" || e == EnvLocal {
		_ = godotenv.Load()
	}
}
