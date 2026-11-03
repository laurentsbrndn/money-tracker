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

// UserRepository reads and writes the users table.
type UserRepository struct {
	db *database.TxManager
}

// NewUserRepository builds the repository.
func NewUserRepository(db *database.TxManager) *UserRepository {
	return &UserRepository{db: db}
}

// Create inserts u. A taken email yields ErrDuplicate.
func (r *UserRepository) Create(ctx context.Context, u *model.User) error {
	if err := r.db.DB(ctx).Create(u).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return ErrDuplicate
		}
		return fmt.Errorf("create user: %w", err)
	}
	return nil
}

// GetByID returns the user, or ErrNotFound.
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*model.User, error) {
	return r.first(r.db.DB(ctx).Where("id = ?", id))
}

// GetByIDForUpdate is GetByID with a row lock; call it inside a transaction.
func (r *UserRepository) GetByIDForUpdate(ctx context.Context, id uuid.UUID) (*model.User, error) {
	return r.first(r.db.DB(ctx).Clauses(clause.Locking{Strength: "UPDATE"}).Where("id = ?", id))
}

// GetByEmail returns the user with the (lowercase) email, or ErrNotFound.
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*model.User, error) {
	return r.first(r.db.DB(ctx).Where("email = ?", email))
}

// GetByEmailForUpdate is GetByEmail with a row lock; call it inside a transaction.
func (r *UserRepository) GetByEmailForUpdate(ctx context.Context, email string) (*model.User, error) {
	return r.first(r.db.DB(ctx).Clauses(clause.Locking{Strength: "UPDATE"}).Where("email = ?", email))
}

func (r *UserRepository) first(q *gorm.DB) (*model.User, error) {
	var u model.User
	if err := q.Take(&u).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("load user: %w", err)
	}
	return &u, nil
}

// UpdateName changes the display name.
func (r *UserRepository) UpdateName(ctx context.Context, id uuid.UUID, name string, now time.Time) error {
	return r.update(ctx, id, map[string]any{"name": name, "updated_at": now})
}

// SetPassword stores a new password hash and clears the lockout state. When verifiedAt is
// not nil it also marks the email verified (if it was not already).
func (r *UserRepository) SetPassword(ctx context.Context, id uuid.UUID, hash string, verifiedAt *time.Time, now time.Time) error {
	fields := map[string]any{
		"password_hash":      hash,
		"failed_login_count": 0,
		"locked_until":       nil,
		"updated_at":         now,
	}
	if verifiedAt != nil {
		fields["email_verified_at"] = gorm.Expr("COALESCE(email_verified_at, ?)", *verifiedAt)
	}
	return r.update(ctx, id, fields)
}

// MarkEmailVerified sets email_verified_at.
func (r *UserRepository) MarkEmailVerified(ctx context.Context, id uuid.UUID, now time.Time) error {
	return r.update(ctx, id, map[string]any{"email_verified_at": now, "updated_at": now})
}

// SaveLoginState stores the failed-login counter and the lockout deadline.
func (r *UserRepository) SaveLoginState(ctx context.Context, id uuid.UUID, failedCount int, lockedUntil *time.Time) error {
	return r.update(ctx, id, map[string]any{
		"failed_login_count": failedCount,
		"locked_until":       lockedUntil,
	})
}

// MarkPendingDeletion flags the account for deletion.
func (r *UserRepository) MarkPendingDeletion(ctx context.Context, id uuid.UUID, now time.Time) error {
	return r.update(ctx, id, map[string]any{
		"status":                model.UserStatusPendingDeletion,
		"deletion_requested_at": now,
		"updated_at":            now,
	})
}

// PendingDeletionBefore returns the ids of users in pending_deletion whose deletion was
// requested before cutoff, oldest request first, at most limit.
func (r *UserRepository) PendingDeletionBefore(ctx context.Context, cutoff time.Time, limit int) ([]uuid.UUID, error) {
	var ids []uuid.UUID
	err := r.db.DB(ctx).Model(&model.User{}).
		Where("status = ? AND deletion_requested_at < ?", model.UserStatusPendingDeletion, cutoff).
		Order("deletion_requested_at, id").Limit(limit).
		Pluck("id", &ids).Error
	if err != nil {
		return nil, fmt.Errorf("list users pending deletion: %w", err)
	}
	return ids, nil
}

// Delete removes the user row; identities and tokens go with it (ON DELETE CASCADE).
func (r *UserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	if err := r.db.DB(ctx).Where("id = ?", id).Delete(&model.User{}).Error; err != nil {
		return fmt.Errorf("delete user: %w", err)
	}
	return nil
}

func (r *UserRepository) update(ctx context.Context, id uuid.UUID, fields map[string]any) error {
	if err := r.db.DB(ctx).Model(&model.User{}).Where("id = ?", id).Updates(fields).Error; err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}
