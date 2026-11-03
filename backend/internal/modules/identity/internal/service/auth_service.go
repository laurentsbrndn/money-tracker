package service

import (
	"context"
	"errors"
	"sync"
	"time"
	_ "time/tzdata" // embed the IANA database; the serverless runtime has no zoneinfo files

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
)

const (
	maxFailedLogins = 10
	lockDuration    = 15 * time.Minute
)

// RegisterInput is the data of an email registration.
type RegisterInput struct {
	Name     string
	Email    string
	Password string
	Timezone string
	Device   Device
}

// LoginInput is the data of an email login.
type LoginInput struct {
	Email    string
	Password string
	Device   Device
}

// AuthService registers and logs in users with email and password.
type AuthService struct {
	db           *database.TxManager
	users        *repository.UserRepository
	views        *UserViewer
	tokens       *TokenService
	verification *VerificationService
	onboarder    Onboarder
	clock        clock.Clock

	dummyOnce sync.Once
	dummyHash string
}

// NewAuthService builds the service.
func NewAuthService(
	db *database.TxManager,
	users *repository.UserRepository,
	views *UserViewer,
	tokens *TokenService,
	verification *VerificationService,
	onboarder Onboarder,
	clk clock.Clock,
) *AuthService {
	return &AuthService{
		db: db, users: users, views: views, tokens: tokens,
		verification: verification, onboarder: onboarder, clock: clk,
	}
}

// Register creates the user, seeds its data, opens a session, and sends the verification code.
// Email is unique across all accounts, including social and pending-deletion ones.
func (s *AuthService) Register(ctx context.Context, in RegisterInput) (AuthResult, error) {
	name := trimmed(in.Name)
	if name == "" {
		return AuthResult{}, validationOn("name", "wajib diisi")
	}
	if err := validateTimezone(in.Timezone); err != nil {
		return AuthResult{}, err
	}
	email := normalizeEmail(in.Email)
	hash, err := auth.HashPassword(in.Password)
	if err != nil {
		return AuthResult{}, err
	}
	userID, err := idgen.NewV7()
	if err != nil {
		return AuthResult{}, err
	}

	now := s.clock.Now()
	user := &model.User{
		ID:           userID,
		Email:        &email,
		PasswordHash: &hash,
		Name:         name,
		Status:       model.UserStatusActive,
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	var tokens Tokens
	var code string
	err = s.db.WithTx(ctx, func(ctx context.Context) error {
		if _, err := s.users.GetByEmail(ctx, email); err == nil {
			return ErrEmailTaken
		} else if !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if err := s.users.Create(ctx, user); err != nil {
			if errors.Is(err, repository.ErrDuplicate) {
				return ErrEmailTaken
			}
			return err
		}
		if err := database.LockUser(ctx, s.db.DB(ctx), userID); err != nil {
			return err
		}
		if err := s.onboarder.Onboard(ctx, userID, in.Timezone); err != nil {
			return err
		}
		if tokens, err = s.tokens.Issue(ctx, userID, uuid.Nil, in.Device); err != nil {
			return err
		}
		code, err = s.verification.CreateCode(ctx, userID, model.PurposeEmailVerification)
		return err
	})
	if err != nil {
		return AuthResult{}, err
	}

	s.verification.SendCode(ctx, email, model.PurposeEmailVerification, code)
	view, err := s.views.View(ctx, user)
	if err != nil {
		return AuthResult{}, err
	}
	return AuthResult{User: view, Tokens: tokens, IsNewUser: true}, nil
}

// Login checks the password and opens a session. Unknown email, social-only accounts, and
// accounts pending deletion all answer invalid_credentials after a dummy hash comparison, so
// neither the response nor its timing reveals which one it was.
func (s *AuthService) Login(ctx context.Context, in LoginInput) (AuthResult, error) {
	user, err := s.users.GetByEmail(ctx, normalizeEmail(in.Email))
	if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return AuthResult{}, err
	}
	if user == nil || user.PasswordHash == nil || user.Status != model.UserStatusActive {
		s.burnPasswordCheck(in.Password)
		return AuthResult{}, ErrInvalidCredentials
	}

	now := s.clock.Now()
	if user.LockedUntil != nil && now.Before(*user.LockedUntil) {
		return AuthResult{}, &LockedError{RetryAfter: user.LockedUntil.Sub(now)}
	}

	ok, err := auth.VerifyPassword(in.Password, *user.PasswordHash)
	if err != nil {
		return AuthResult{}, err
	}
	if !ok {
		return AuthResult{}, s.recordFailedLogin(ctx, user.ID)
	}

	var tokens Tokens
	err = s.db.WithTx(ctx, func(ctx context.Context) error {
		if user.FailedLoginCount > 0 || user.LockedUntil != nil {
			if err := s.users.SaveLoginState(ctx, user.ID, 0, nil); err != nil {
				return err
			}
		}
		tokens, err = s.tokens.Issue(ctx, user.ID, uuid.Nil, in.Device)
		return err
	})
	if err != nil {
		return AuthResult{}, err
	}
	view, err := s.views.View(ctx, user)
	if err != nil {
		return AuthResult{}, err
	}
	return AuthResult{User: view, Tokens: tokens}, nil
}

// recordFailedLogin counts a failed attempt under a row lock. The 10th failure locks the
// account for 15 minutes and restarts the counter. The returned error is what the caller
// answers: account_locked on the attempt that triggers the lock, invalid_credentials otherwise.
func (s *AuthService) recordFailedLogin(ctx context.Context, userID uuid.UUID) error {
	var outcome error
	err := s.db.WithTx(ctx, func(ctx context.Context) error {
		user, err := s.users.GetByIDForUpdate(ctx, userID)
		if err != nil {
			return mapUserError(err)
		}
		now := s.clock.Now()
		if user.LockedUntil != nil && now.Before(*user.LockedUntil) {
			outcome = &LockedError{RetryAfter: user.LockedUntil.Sub(now)}
			return nil
		}
		count := user.FailedLoginCount + 1
		if count < maxFailedLogins {
			return s.users.SaveLoginState(ctx, userID, count, nil)
		}
		until := now.Add(lockDuration)
		outcome = &LockedError{RetryAfter: lockDuration}
		return s.users.SaveLoginState(ctx, userID, 0, &until)
	})
	if err != nil {
		return err
	}
	if outcome == nil {
		return ErrInvalidCredentials
	}
	return outcome
}

// burnPasswordCheck spends the time of one password verification against a throwaway hash.
func (s *AuthService) burnPasswordCheck(password string) {
	s.dummyOnce.Do(func() {
		s.dummyHash, _ = auth.HashPassword("dummy-password-for-timing")
	})
	if s.dummyHash != "" {
		_, _ = auth.VerifyPassword(password, s.dummyHash)
	}
}

func validateTimezone(name string) error {
	if name == "" || name == "Local" {
		return validationOn("timezone", "bukan nama timezone IANA yang valid")
	}
	if _, err := time.LoadLocation(name); err != nil {
		return validationOn("timezone", "bukan nama timezone IANA yang valid")
	}
	return nil
}
