package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/platform/database"
)

// RefreshTokenRepository reads and writes the refresh_tokens table.
type RefreshTokenRepository struct {
	db *database.TxManager
}

// NewRefreshTokenRepository builds the repository.
func NewRefreshTokenRepository(db *database.TxManager) *RefreshTokenRepository {
	return &RefreshTokenRepository{db: db}
}

// Create inserts a token.
func (r *RefreshTokenRepository) Create(ctx context.Context, t *model.RefreshToken) error {
	if err := r.db.DB(ctx).Create(t).Error; err != nil {
		return fmt.Errorf("create refresh token: %w", err)
	}
	return nil
}

// RevokeAllForUser revokes every live token of the user.
func (r *RefreshTokenRepository) RevokeAllForUser(ctx context.Context, userID uuid.UUID, now time.Time) error {
	err := r.db.DB(ctx).Model(&model.RefreshToken{}).
		Where("user_id = ? AND revoked_at IS NULL", userID).
		Update("revoked_at", now).Error
	if err != nil {
		return fmt.Errorf("revoke user tokens: %w", err)
	}
	return nil
}

// RevokeAllExceptFamily revokes the user's live tokens outside one session.
func (r *RefreshTokenRepository) RevokeAllExceptFamily(ctx context.Context, userID, keepFamily uuid.UUID, now time.Time) error {
	err := r.db.DB(ctx).Model(&model.RefreshToken{}).
		Where("user_id = ? AND family_id <> ? AND revoked_at IS NULL", userID, keepFamily).
		Update("revoked_at", now).Error
	if err != nil {
		return fmt.Errorf("revoke other sessions: %w", err)
	}
	return nil
}

// FindByHashForUpdate returns the token with the given hash under a row lock, or ErrNotFound.
// Call it inside a transaction.
func (r *RefreshTokenRepository) FindByHashForUpdate(ctx context.Context, hash string) (*model.RefreshToken, error) {
	var t model.RefreshToken
	err := r.db.DB(ctx).Clauses(clause.Locking{Strength: "UPDATE"}).Where("token_hash = ?", hash).Take(&t).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("load refresh token: %w", err)
	}
	return &t, nil
}

// MarkRotated sets rotated_at, but only while the token has not been rotated yet. It reports
// whether this call did the rotation.
func (r *RefreshTokenRepository) MarkRotated(ctx context.Context, id uuid.UUID, now time.Time) (bool, error) {
	res := r.db.DB(ctx).Model(&model.RefreshToken{}).
		Where("id = ? AND rotated_at IS NULL", id).
		Update("rotated_at", now)
	if res.Error != nil {
		return false, fmt.Errorf("rotate refresh token: %w", res.Error)
	}
	return res.RowsAffected == 1, nil
}

// RevokeFamily revokes every live token of one session.
func (r *RefreshTokenRepository) RevokeFamily(ctx context.Context, familyID uuid.UUID, now time.Time) error {
	err := r.db.DB(ctx).Model(&model.RefreshToken{}).
		Where("family_id = ? AND revoked_at IS NULL", familyID).
		Update("revoked_at", now).Error
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}
