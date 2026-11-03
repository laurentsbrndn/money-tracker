package service

import (
	"context"
	"strings"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
)

// deleteConfirmation is what a social-only user types to confirm account deletion.
const deleteConfirmation = "HAPUS"

// AccountService serves the profile endpoints and password changes.
type AccountService struct {
	db           *database.TxManager
	users        *repository.UserRepository
	refresh      *repository.RefreshTokenRepository
	views        *UserViewer
	entitlements EntitlementReader
	clock        clock.Clock
}

// NewAccountService builds the service.
func NewAccountService(
	db *database.TxManager,
	users *repository.UserRepository,
	refresh *repository.RefreshTokenRepository,
	views *UserViewer,
	entitlements EntitlementReader,
	clk clock.Clock,
) *AccountService {
	return &AccountService{db: db, users: users, refresh: refresh, views: views, entitlements: entitlements, clock: clk}
}

// Me returns the profile and the entitlement.
func (s *AccountService) Me(ctx context.Context, userID uuid.UUID) (UserView, Entitlement, error) {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return UserView{}, Entitlement{}, mapUserError(err)
	}
	view, err := s.views.View(ctx, user)
	if err != nil {
		return UserView{}, Entitlement{}, err
	}
	ent, err := s.entitlements.Entitlement(ctx, userID)
	if err != nil {
		return UserView{}, Entitlement{}, err
	}
	return view, ent, nil
}

// Get returns the profile.
func (s *AccountService) Get(ctx context.Context, userID uuid.UUID) (UserView, error) {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return UserView{}, mapUserError(err)
	}
	return s.views.View(ctx, user)
}

// UpdateName changes the display name.
func (s *AccountService) UpdateName(ctx context.Context, userID uuid.UUID, name string) (UserView, error) {
	name = trimmed(name)
	if name == "" {
		return UserView{}, validationOn("name", "wajib diisi")
	}
	if err := s.users.UpdateName(ctx, userID, name, s.clock.Now()); err != nil {
		return UserView{}, err
	}
	return s.Get(ctx, userID)
}

// ChangePassword replaces the password and revokes every session except the current one.
// A user without a password (social login) must use the forgot-password flow instead.
func (s *AccountService) ChangePassword(ctx context.Context, userID, sessionID uuid.UUID, current, next string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return mapUserError(err)
	}
	if user.PasswordHash == nil {
		return &ValidationError{Message: "gunakan lupa password"}
	}
	ok, err := auth.VerifyPassword(current, *user.PasswordHash)
	if err != nil {
		return err
	}
	if !ok {
		return ErrInvalidCredentials
	}
	hash, err := auth.HashPassword(next)
	if err != nil {
		return err
	}

	now := s.clock.Now()
	return s.db.WithTx(ctx, func(ctx context.Context) error {
		if err := s.users.SetPassword(ctx, userID, hash, nil, now); err != nil {
			return err
		}
		return s.refresh.RevokeAllExceptFamily(ctx, userID, sessionID, now)
	})
}

// Delete schedules the account for deletion and revokes every session. Users with a password
// confirm with it; social-only users type HAPUS.
func (s *AccountService) Delete(ctx context.Context, userID uuid.UUID, confirmation string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return mapUserError(err)
	}
	if user.PasswordHash != nil {
		ok, err := auth.VerifyPassword(confirmation, *user.PasswordHash)
		if err != nil {
			return err
		}
		if !ok {
			return ErrInvalidCredentials
		}
	} else if confirmation != deleteConfirmation {
		return validationOn("confirmation", "ketik HAPUS untuk mengonfirmasi")
	}

	now := s.clock.Now()
	return s.db.WithTx(ctx, func(ctx context.Context) error {
		if err := s.users.MarkPendingDeletion(ctx, userID, now); err != nil {
			return err
		}
		return s.refresh.RevokeAllForUser(ctx, userID, now)
	})
}

func trimmed(s string) string {
	return strings.TrimSpace(s)
}
