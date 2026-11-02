package config

import (
	"errors"
	"strings"
)

// AppleConfig is used by identity OAuth (Phase 1).
type AppleConfig struct {
	BundleID string `env:"APPLE_BUNDLE_ID"`
}

// Validate checks the fields required once Apple login is wired.
func (c AppleConfig) Validate() error {
	if strings.TrimSpace(c.BundleID) == "" {
		return errors.New("APPLE_BUNDLE_ID must not be empty")
	}
	return nil
}

// GoogleConfig is used by identity OAuth (Phase 1).
type GoogleConfig struct {
	ClientIDs []string `env:"GOOGLE_CLIENT_IDS" envSeparator:","`
}

// Validate checks the fields required once Google login is wired.
func (c GoogleConfig) Validate() error {
	if len(c.ClientIDs) == 0 {
		return errors.New("GOOGLE_CLIENT_IDS must contain at least one client ID")
	}
	return nil
}

// EmailConfig is used by identity for verification and reset codes (Phase 1).
type EmailConfig struct {
	ResendAPIKey string `env:"RESEND_API_KEY"`
	From         string `env:"EMAIL_FROM"`
}

// Validate checks the fields required once the mailer is wired. The Resend key may stay
// empty outside production, in which case the log mailer is used.
func (c EmailConfig) Validate(production bool) error {
	var errs []error
	if strings.TrimSpace(c.From) == "" {
		errs = append(errs, errors.New("EMAIL_FROM must not be empty"))
	}
	if production && strings.TrimSpace(c.ResendAPIKey) == "" {
		errs = append(errs, errors.New("RESEND_API_KEY must not be empty in production"))
	}
	return errors.Join(errs...)
}

// RevenueCatConfig is used by billing (Phase 3).
type RevenueCatConfig struct {
	WebhookSecret string `env:"REVENUECAT_WEBHOOK_SECRET"`
	SecretAPIKey  string `env:"REVENUECAT_SECRET_API_KEY"`
}

// Validate checks the fields required once billing is wired.
func (c RevenueCatConfig) Validate() error {
	var errs []error
	if strings.TrimSpace(c.WebhookSecret) == "" {
		errs = append(errs, errors.New("REVENUECAT_WEBHOOK_SECRET must not be empty"))
	}
	if strings.TrimSpace(c.SecretAPIKey) == "" {
		errs = append(errs, errors.New("REVENUECAT_SECRET_API_KEY must not be empty"))
	}
	return errors.Join(errs...)
}
