package app

import (
	"context"
	"errors"
	"fmt"
	"log/slog"

	"moneytracker/internal/modules/identity"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/config"
	"moneytracker/internal/platform/mailer"
)

// buildMailer validates the email config and picks the mailer: Resend when RESEND_API_KEY is
// set, otherwise the log mailer (local development; the code is written to the log).
// EMAIL_FROM is required everywhere; RESEND_API_KEY only in production.
func buildMailer(cfg config.Config, log *slog.Logger) (mailer.Mailer, error) {
	if err := cfg.Email.Validate(cfg.IsProduction()); err != nil {
		return nil, fmt.Errorf("email configuration: %w", err)
	}
	if cfg.Email.ResendAPIKey == "" {
		log.Warn("RESEND_API_KEY is empty: emails are written to the log, not sent")
		return mailer.NewLogMailer(log), nil
	}
	return mailer.NewResendMailer(cfg.Email.ResendAPIKey, cfg.Email.From), nil
}

// buildVerifiers returns the Apple and Google ID token verifiers. Outside local, missing
// config stops the server from starting. In local a missing provider stays nil, and its
// endpoint answers "OAuth belum dikonfigurasi". The verifiers load their key sets lazily on
// first use, so start-up never depends on Apple or Google being reachable. base must live as
// long as the app (the key sets refresh in the background).
func buildVerifiers(base context.Context, cfg config.Config, log *slog.Logger) (apple, google identity.IDTokenVerifier, err error) {
	appleErr := cfg.Apple.Validate()
	googleErr := cfg.Google.Validate()
	if cfg.AppEnv != config.EnvLocal {
		if err := errors.Join(appleErr, googleErr); err != nil {
			return nil, nil, fmt.Errorf("oauth configuration: %w", err)
		}
	}

	if appleErr == nil {
		apple = auth.NewLazyOIDCVerifier(base, func(ctx context.Context) (*auth.OIDCVerifier, error) {
			return auth.NewAppleVerifier(ctx, cfg.Apple.BundleID)
		})
	} else {
		log.Warn("Apple login disabled", "reason", appleErr)
	}
	if googleErr == nil {
		google = auth.NewLazyOIDCVerifier(base, func(ctx context.Context) (*auth.OIDCVerifier, error) {
			return auth.NewGoogleVerifier(ctx, cfg.Google.ClientIDs)
		})
	} else {
		log.Warn("Google login disabled", "reason", googleErr)
	}
	return apple, google, nil
}
