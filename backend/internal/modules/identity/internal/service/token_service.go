package service

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
)

const (
	maxDeviceNameLen = 100
	maxIPLen         = 45
)

// TokenService issues, rotates, and revokes access/refresh token pairs.
type TokenService struct {
	db         *database.TxManager
	users      *repository.UserRepository
	refresh    *repository.RefreshTokenRepository
	jwt        *auth.JWT
	clock      clock.Clock
	refreshTTL time.Duration
}

// NewTokenService builds the service.
func NewTokenService(
	db *database.TxManager,
	users *repository.UserRepository,
	refresh *repository.RefreshTokenRepository,
	jwt *auth.JWT,
	clk clock.Clock,
	refreshTTL time.Duration,
) *TokenService {
	return &TokenService{db: db, users: users, refresh: refresh, jwt: jwt, clock: clk, refreshTTL: refreshTTL}
}

// Issue creates a refresh token in familyID (a new family when it is uuid.Nil) and signs an
// access token for the same session. Run it inside the caller's transaction.
func (s *TokenService) Issue(ctx context.Context, userID, familyID uuid.UUID, device Device) (Tokens, error) {
	if familyID == uuid.Nil {
		id, err := idgen.NewV7()
		if err != nil {
			return Tokens{}, err
		}
		familyID = id
	}
	id, err := idgen.NewV7()
	if err != nil {
		return Tokens{}, err
	}
	token, hash, err := auth.NewRefreshToken()
	if err != nil {
		return Tokens{}, err
	}

	now := s.clock.Now()
	row := &model.RefreshToken{
		ID:         id,
		UserID:     userID,
		FamilyID:   familyID,
		TokenHash:  hash,
		DeviceID:   device.ID,
		DeviceName: optional(device.Name, maxDeviceNameLen),
		IPAddress:  optional(device.IP, maxIPLen),
		ExpiresAt:  now.Add(s.refreshTTL),
		CreatedAt:  now,
	}
	if err := s.refresh.Create(ctx, row); err != nil {
		return Tokens{}, err
	}

	access, accessExpires, err := s.jwt.Issue(userID, familyID)
	if err != nil {
		return Tokens{}, fmt.Errorf("issue access token: %w", err)
	}
	return Tokens{
		AccessToken:      access,
		AccessExpiresAt:  accessExpires,
		RefreshToken:     token,
		RefreshExpiresAt: row.ExpiresAt,
	}, nil
}

// Refresh rotates a refresh token (docs/BACKEND.md §6.1): the old token is marked rotated and a
// new one is issued in the same family (sliding expiry).
//
//   - Unknown, expired, or revoked token → ErrRefreshInvalid.
//   - A token that was already rotated is a replay: the whole family is revoked and the
//     answer is ErrRefreshReused. The revocation commits even though an error is returned.
//   - Rotation is a conditional update under a row lock, so two parallel refreshes with the
//     same token cannot both succeed; the loser counts as a replay.
func (s *TokenService) Refresh(ctx context.Context, token string, device Device) (Tokens, error) {
	if token == "" {
		return Tokens{}, ErrRefreshInvalid
	}

	var tokens Tokens
	var outcome error
	err := s.db.WithTx(ctx, func(ctx context.Context) error {
		current, err := s.refresh.FindByHashForUpdate(ctx, auth.HashRefreshToken(token))
		if err != nil {
			if errors.Is(err, repository.ErrNotFound) {
				outcome = ErrRefreshInvalid
				return nil
			}
			return err
		}

		now := s.clock.Now()
		switch {
		case current.RevokedAt != nil || now.After(current.ExpiresAt):
			outcome = ErrRefreshInvalid
			return nil
		case current.RotatedAt != nil:
			outcome = ErrRefreshReused
			return s.refresh.RevokeFamily(ctx, current.FamilyID, now)
		}

		user, err := s.users.GetByID(ctx, current.UserID)
		if err != nil && !errors.Is(err, repository.ErrNotFound) {
			return err
		}
		if user == nil || user.Status != model.UserStatusActive {
			outcome = ErrRefreshInvalid
			return s.refresh.RevokeFamily(ctx, current.FamilyID, now)
		}

		rotated, err := s.refresh.MarkRotated(ctx, current.ID, now)
		if err != nil {
			return err
		}
		if !rotated {
			outcome = ErrRefreshReused
			return s.refresh.RevokeFamily(ctx, current.FamilyID, now)
		}
		tokens, err = s.Issue(ctx, current.UserID, current.FamilyID, device)
		return err
	})
	if err != nil {
		return Tokens{}, err
	}
	if outcome != nil {
		return Tokens{}, outcome
	}
	return tokens, nil
}

// Logout revokes the whole session (family) the refresh token belongs to. An unknown token
// is not an error: logout is idempotent.
func (s *TokenService) Logout(ctx context.Context, token string) error {
	if token == "" {
		return nil
	}
	return s.db.WithTx(ctx, func(ctx context.Context) error {
		current, err := s.refresh.FindByHashForUpdate(ctx, auth.HashRefreshToken(token))
		if err != nil {
			if errors.Is(err, repository.ErrNotFound) {
				return nil
			}
			return err
		}
		return s.refresh.RevokeFamily(ctx, current.FamilyID, s.clock.Now())
	})
}

// optional returns nil for an empty string and truncates to max bytes otherwise.
func optional(s string, max int) *string {
	if s == "" {
		return nil
	}
	if len(s) > max {
		s = s[:max]
	}
	return &s
}
