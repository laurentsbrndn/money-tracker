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

// VerificationTokenRepository reads and writes the verification_tokens table.
type VerificationTokenRepository struct {
	db *database.TxManager
}

// NewVerificationTokenRepository builds the repository.
func NewVerificationTokenRepository(db *database.TxManager) *VerificationTokenRepository {
	return &VerificationTokenRepository{db: db}
}

// Create inserts a token.
func (r *VerificationTokenRepository) Create(ctx context.Context, t *model.VerificationToken) error {
	if err := r.db.DB(ctx).Create(t).Error; err != nil {
		return fmt.Errorf("create verification token: %w", err)
	}
	return nil
}

// Latest returns the newest token for (user, purpose), used or not, or ErrNotFound.
func (r *VerificationTokenRepository) Latest(ctx context.Context, userID uuid.UUID, purpose string) (*model.VerificationToken, error) {
	return r.latest(r.db.DB(ctx), userID, purpose)
}

// LatestForUpdate is Latest with a row lock; call it inside a transaction.
func (r *VerificationTokenRepository) LatestForUpdate(ctx context.Context, userID uuid.UUID, purpose string) (*model.VerificationToken, error) {
	return r.latest(r.db.DB(ctx).Clauses(clause.Locking{Strength: "UPDATE"}), userID, purpose)
}

func (r *VerificationTokenRepository) latest(q *gorm.DB, userID uuid.UUID, purpose string) (*model.VerificationToken, error) {
	var t model.VerificationToken
	err := q.Where("user_id = ? AND purpose = ?", userID, purpose).Order("created_at DESC").Take(&t).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("load verification token: %w", err)
	}
	return &t, nil
}

// InvalidateOpen marks every unused token of (user, purpose) as used, so only the next
// token created is valid.
func (r *VerificationTokenRepository) InvalidateOpen(ctx context.Context, userID uuid.UUID, purpose string, now time.Time) error {
	err := r.db.DB(ctx).Model(&model.VerificationToken{}).
		Where("user_id = ? AND purpose = ? AND used_at IS NULL", userID, purpose).
		Update("used_at", now).Error
	if err != nil {
		return fmt.Errorf("invalidate verification tokens: %w", err)
	}
	return nil
}

// SetAttempts stores the number of wrong attempts.
func (r *VerificationTokenRepository) SetAttempts(ctx context.Context, id uuid.UUID, attempts int16) error {
	err := r.db.DB(ctx).Model(&model.VerificationToken{}).Where("id = ?", id).Update("attempts", attempts).Error
	if err != nil {
		return fmt.Errorf("update verification attempts: %w", err)
	}
	return nil
}

// MarkUsed consumes the token.
func (r *VerificationTokenRepository) MarkUsed(ctx context.Context, id uuid.UUID, now time.Time) error {
	err := r.db.DB(ctx).Model(&model.VerificationToken{}).Where("id = ?", id).Update("used_at", now).Error
	if err != nil {
		return fmt.Errorf("mark verification token used: %w", err)
	}
	return nil
}
