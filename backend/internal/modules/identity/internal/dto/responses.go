package dto

import (
	"time"

	"moneytracker/internal/modules/identity/internal/service"
)

// timestampLayout is RFC 3339 UTC with milliseconds, like every timestamp on the wire.
const timestampLayout = "2006-01-02T15:04:05.000Z"

// User is the user object shared by every auth response.
type User struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	Email         *string  `json:"email"`
	EmailVerified bool     `json:"email_verified"`
	HasPassword   bool     `json:"has_password"`
	Providers     []string `json:"providers"`
}

// Tokens is the access/refresh token pair.
type Tokens struct {
	AccessToken      string `json:"access_token"`
	AccessExpiresAt  string `json:"access_expires_at"`
	RefreshToken     string `json:"refresh_token"`
	RefreshExpiresAt string `json:"refresh_expires_at"`
}

// AuthResponse is returned by register, login, and OAuth login.
type AuthResponse struct {
	User      User   `json:"user"`
	Tokens    Tokens `json:"tokens"`
	IsNewUser bool   `json:"is_new_user"`
}

// RefreshResponse is returned by POST /v1/auth/refresh.
type RefreshResponse struct {
	Tokens Tokens `json:"tokens"`
}

// UserEnvelope wraps a user (verify email, PATCH /me).
type UserEnvelope struct {
	User User `json:"user"`
}

// Entitlement is the premium status. product_id and store appear only with a subscription.
type Entitlement struct {
	Premium   bool    `json:"premium"`
	ExpiresAt *string `json:"expires_at"`
	WillRenew bool    `json:"will_renew"`
	ProductID string  `json:"product_id,omitempty"`
	Store     string  `json:"store,omitempty"`
}

// MeResponse is returned by GET /v1/me.
type MeResponse struct {
	User        User        `json:"user"`
	Entitlement Entitlement `json:"entitlement"`
}

// NewUser shapes a service user for the wire.
func NewUser(u service.UserView) User {
	return User{
		ID:            u.ID.String(),
		Name:          u.Name,
		Email:         u.Email,
		EmailVerified: u.EmailVerified,
		HasPassword:   u.HasPassword,
		Providers:     u.Providers,
	}
}

// NewTokens shapes a token pair for the wire.
func NewTokens(t service.Tokens) Tokens {
	return Tokens{
		AccessToken:      t.AccessToken,
		AccessExpiresAt:  formatTime(t.AccessExpiresAt),
		RefreshToken:     t.RefreshToken,
		RefreshExpiresAt: formatTime(t.RefreshExpiresAt),
	}
}

// NewAuthResponse shapes an auth result for the wire.
func NewAuthResponse(r service.AuthResult) AuthResponse {
	return AuthResponse{User: NewUser(r.User), Tokens: NewTokens(r.Tokens), IsNewUser: r.IsNewUser}
}

// NewEntitlement shapes an entitlement for the wire.
func NewEntitlement(e service.Entitlement) Entitlement {
	out := Entitlement{Premium: e.Premium, WillRenew: e.WillRenew, ProductID: e.ProductID, Store: e.Store}
	if e.ExpiresAt != nil {
		s := formatTime(*e.ExpiresAt)
		out.ExpiresAt = &s
	}
	return out
}

func formatTime(t time.Time) string {
	return t.UTC().Format(timestampLayout)
}
