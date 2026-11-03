package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/platform/database"
)

// AuthIdentityRepository reads and writes the auth_identities table.
type AuthIdentityRepository struct {
	db *database.TxManager
}

// NewAuthIdentityRepository builds the repository.
func NewAuthIdentityRepository(db *database.TxManager) *AuthIdentityRepository {
	return &AuthIdentityRepository{db: db}
}

// Providers lists the providers linked to the user, oldest first.
func (r *AuthIdentityRepository) Providers(ctx context.Context, userID uuid.UUID) ([]string, error) {
	var providers []string
	err := r.db.DB(ctx).Model(&model.AuthIdentity{}).
		Where("user_id = ?", userID).Order("created_at").Pluck("provider", &providers).Error
	if err != nil {
		return nil, fmt.Errorf("list providers: %w", err)
	}
	return providers, nil
}

// FindBySubject returns the identity of (provider, subject), or ErrNotFound.
func (r *AuthIdentityRepository) FindBySubject(ctx context.Context, provider, subject string) (*model.AuthIdentity, error) {
	var ident model.AuthIdentity
	err := r.db.DB(ctx).Where("provider = ? AND provider_subject = ?", provider, subject).Take(&ident).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("load auth identity: %w", err)
	}
	return &ident, nil
}

// Create links an identity to a user. An identity that already exists yields ErrDuplicate.
func (r *AuthIdentityRepository) Create(ctx context.Context, ident *model.AuthIdentity) error {
	if err := r.db.DB(ctx).Create(ident).Error; err != nil {
		if errors.Is(err, gorm.ErrDuplicatedKey) {
			return ErrDuplicate
		}
		return fmt.Errorf("create auth identity: %w", err)
	}
	return nil
}
