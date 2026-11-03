package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
	"moneytracker/internal/platform/mailer"
)

const (
	codeTTL        = 15 * time.Minute
	maxCodeTries   = 5
	resendInterval = 60 * time.Second
)

// VerificationService handles the 6-digit codes for email verification and password reset
// (docs/API.md §2): valid 15 minutes, 5 wrong attempts at most, only the newest code counts.
type VerificationService struct {
	db      *database.TxManager
	users   *repository.UserRepository
	tokens  *repository.VerificationTokenRepository
	refresh *repository.RefreshTokenRepository
	views   *UserViewer
	otp     *auth.OTP
	mailer  mailer.Mailer
	clock   clock.Clock
	log     *slog.Logger
}

// NewVerificationService builds the service.
func NewVerificationService(
	db *database.TxManager,
	users *repository.UserRepository,
	tokens *repository.VerificationTokenRepository,
	refresh *repository.RefreshTokenRepository,
	views *UserViewer,
	otp *auth.OTP,
	mail mailer.Mailer,
	clk clock.Clock,
	log *slog.Logger,
) *VerificationService {
	return &VerificationService{
		db: db, users: users, tokens: tokens, refresh: refresh, views: views,
		otp: otp, mailer: mail, clock: clk, log: log,
	}
}

// CreateCode invalidates the open codes of (user, purpose) and stores a new one. It returns
// the plain code; send it with SendCode after the transaction commits.
func (s *VerificationService) CreateCode(ctx context.Context, userID uuid.UUID, purpose string) (string, error) {
	code, err := s.otp.Generate()
	if err != nil {
		return "", err
	}
	id, err := idgen.NewV7()
	if err != nil {
		return "", err
	}
	now := s.clock.Now()
	if err := s.tokens.InvalidateOpen(ctx, userID, purpose, now); err != nil {
		return "", err
	}
	row := &model.VerificationToken{
		ID:        id,
		UserID:    userID,
		Purpose:   purpose,
		CodeHash:  s.otp.Hash(code, userID),
		ExpiresAt: now.Add(codeTTL),
		CreatedAt: now,
	}
	if err := s.tokens.Create(ctx, row); err != nil {
		return "", err
	}
	return code, nil
}

// SendCode emails the code. Delivery failures are logged, not returned: the caller's request
// already succeeded and the user can ask for a new code.
func (s *VerificationService) SendCode(ctx context.Context, to, purpose, code string) {
	subject := "Kode verifikasi email Money Tracker"
	intro := "Kode verifikasi email Anda"
	if purpose == model.PurposePasswordReset {
		subject = "Kode reset password Money Tracker"
		intro = "Kode reset password Anda"
	}
	text := fmt.Sprintf("%s: %s\n\nKode berlaku 15 menit. Jangan bagikan kode ini kepada siapa pun.", intro, code)
	if err := s.mailer.Send(ctx, mailer.Message{To: to, Subject: subject, Text: text}); err != nil {
		s.log.ErrorContext(ctx, "send verification email failed", "purpose", purpose, "error", err)
	}
}

// ResendEmailVerification sends a new verification code to the user's email, at most once
// per 60 seconds. An already verified email is a no-op.
func (s *VerificationService) ResendEmailVerification(ctx context.Context, userID uuid.UUID) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return mapUserError(err)
	}
	if user.EmailVerifiedAt != nil {
		return nil
	}
	if user.Email == nil {
		return validationOn("email", "akun tidak memiliki email")
	}

	var code string
	err = s.db.WithTx(ctx, func(ctx context.Context) error {
		latest, err := s.tokens.LatestForUpdate(ctx, userID, model.PurposeEmailVerification)
		if err != nil && !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if latest != nil && s.clock.Now().Sub(latest.CreatedAt) < resendInterval {
			return ErrRateLimited
		}
		code, err = s.CreateCode(ctx, userID, model.PurposeEmailVerification)
		return err
	})
	if err != nil {
		return err
	}
	s.SendCode(ctx, *user.Email, model.PurposeEmailVerification, code)
	return nil
}

// VerifyEmail checks the code and marks the email verified.
func (s *VerificationService) VerifyEmail(ctx context.Context, userID uuid.UUID, code string) (UserView, error) {
	err := s.consume(ctx, userID, model.PurposeEmailVerification, code, func(ctx context.Context) error {
		return s.users.MarkEmailVerified(ctx, userID, s.clock.Now())
	})
	if err != nil {
		return UserView{}, err
	}
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return UserView{}, mapUserError(err)
	}
	return s.views.View(ctx, user)
}

// ForgotPassword emails a reset code. It never reveals whether the email is registered:
// unknown, social-only without email, deleted, or throttled requests all end silently.
func (s *VerificationService) ForgotPassword(ctx context.Context, email string) error {
	user, err := s.users.GetByEmail(ctx, normalizeEmail(email))
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil
		}
		return err
	}
	if user.Status != model.UserStatusActive {
		return nil
	}

	var code string
	var skipped bool
	err = s.db.WithTx(ctx, func(ctx context.Context) error {
		latest, err := s.tokens.LatestForUpdate(ctx, user.ID, model.PurposePasswordReset)
		if err != nil && !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if latest != nil && s.clock.Now().Sub(latest.CreatedAt) < resendInterval {
			skipped = true
			return nil
		}
		code, err = s.CreateCode(ctx, user.ID, model.PurposePasswordReset)
		return err
	})
	if err != nil || skipped {
		return err
	}
	s.SendCode(ctx, *user.Email, model.PurposePasswordReset, code)
	return nil
}

// ResetPassword sets a new password with a reset code. It also marks the email verified (the
// code proved ownership), clears any lockout, and revokes every refresh token of the user.
func (s *VerificationService) ResetPassword(ctx context.Context, email, code, newPassword string) error {
	user, err := s.users.GetByEmail(ctx, normalizeEmail(email))
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrCodeInvalid
		}
		return err
	}
	if user.Status != model.UserStatusActive {
		return ErrCodeInvalid
	}

	return s.consume(ctx, user.ID, model.PurposePasswordReset, code, func(ctx context.Context) error {
		hash, err := auth.HashPassword(newPassword)
		if err != nil {
			return err
		}
		now := s.clock.Now()
		if err := s.users.SetPassword(ctx, user.ID, hash, &now, now); err != nil {
			return err
		}
		return s.refresh.RevokeAllForUser(ctx, user.ID, now)
	})
}

// consume validates code against the newest token of (user, purpose) and, when it is right,
// marks it used and runs apply in the same transaction. A wrong code increments the attempt
// counter, which is committed even though an error is returned.
func (s *VerificationService) consume(ctx context.Context, userID uuid.UUID, purpose, code string, apply func(ctx context.Context) error) error {
	var outcome error
	err := s.db.WithTx(ctx, func(ctx context.Context) error {
		token, err := s.tokens.LatestForUpdate(ctx, userID, purpose)
		if err != nil {
			if errors.Is(err, repository.ErrNotFound) {
				outcome = ErrCodeInvalid
				return nil
			}
			return err
		}
		now := s.clock.Now()
		switch {
		case token.UsedAt != nil:
			outcome = ErrCodeInvalid
		case token.Attempts >= maxCodeTries:
			outcome = ErrTooManyAttempts
		case now.After(token.ExpiresAt):
			outcome = ErrCodeExpired
		case !s.otp.Verify(code, userID, token.CodeHash):
			token.Attempts++
			if err := s.tokens.SetAttempts(ctx, token.ID, token.Attempts); err != nil {
				return err
			}
			outcome = ErrCodeInvalid
			if token.Attempts >= maxCodeTries {
				outcome = ErrTooManyAttempts
			}
		default:
			if err := s.tokens.MarkUsed(ctx, token.ID, now); err != nil {
				return err
			}
			return apply(ctx)
		}
		return nil
	})
	if err != nil {
		return err
	}
	return outcome
}

func normalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func mapUserError(err error) error {
	if errors.Is(err, repository.ErrNotFound) {
		return ErrUserNotFound
	}
	return err
}
