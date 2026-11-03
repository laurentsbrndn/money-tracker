package service

import (
	"context"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
)

// UserView is the public shape of a user (docs/API.md §2).
type UserView struct {
	ID            uuid.UUID
	Name          string
	Email         *string
	EmailVerified bool
	HasPassword   bool
	Providers     []string
}

// Device identifies the app installation behind a request. IP is for session audit only.
type Device struct {
	ID   string
	Name string
	IP   string
}

// Tokens is a fresh access/refresh token pair.
type Tokens struct {
	AccessToken      string
	AccessExpiresAt  time.Time
	RefreshToken     string
	RefreshExpiresAt time.Time
}

// AuthResult is the outcome of register, login, and OAuth login.
type AuthResult struct {
	User      UserView
	Tokens    Tokens
	IsNewUser bool
}

// UserViewer builds UserView values.
type UserViewer struct {
	identities *repository.AuthIdentityRepository
}

// NewUserViewer builds the viewer.
func NewUserViewer(identities *repository.AuthIdentityRepository) *UserViewer {
	return &UserViewer{identities: identities}
}

// View loads the linked providers and shapes u for the API.
func (v *UserViewer) View(ctx context.Context, u *model.User) (UserView, error) {
	providers, err := v.identities.Providers(ctx, u.ID)
	if err != nil {
		return UserView{}, err
	}
	if providers == nil {
		providers = []string{}
	}
	return UserView{
		ID:            u.ID,
		Name:          u.Name,
		Email:         u.Email,
		EmailVerified: u.EmailVerifiedAt != nil,
		HasPassword:   u.PasswordHash != nil,
		Providers:     providers,
	}, nil
}
