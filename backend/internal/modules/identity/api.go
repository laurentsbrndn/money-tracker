// Package identity owns users, login sessions, and verification codes. Other modules use
// only the interfaces in this file (docs/ARCHITECTURE.md §3).
package identity

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/service"
)

// Onboarder seeds a new user's data inside the registration transaction. It is implemented
// by the composition root, so identity does not import the modules that own the seed data.
type Onboarder = service.Onboarder

// Entitlement is the premium status shown by GET /v1/me.
type Entitlement = service.Entitlement

// EntitlementReader supplies the entitlement for GET /v1/me. The composition root adapts
// billing.Entitlements to it, because identity cannot import billing.
type EntitlementReader = service.EntitlementReader

// IDTokenVerifier verifies Apple and Google ID tokens (auth.LazyOIDCVerifier implements it).
type IDTokenVerifier = service.IDTokenVerifier

// UserPurger permanently deletes a user's data. Every module implements it for the
// maintenance job that removes accounts pending deletion.
type UserPurger interface {
	PurgeUser(ctx context.Context, userID uuid.UUID) error
}

// User is the public profile of a user.
type User struct {
	ID            uuid.UUID
	Name          string
	Email         *string
	EmailVerified bool
	HasPassword   bool
	Providers     []string
}

// Users reads user profiles.
type Users interface {
	// Get returns the user, or an error wrapping ErrUserNotFound.
	Get(ctx context.Context, userID uuid.UUID) (User, error)
}

// Settings creates and reads the settings row. The Onboarder (composition root) calls
// CreateDefault inside the registration transaction; the composition root also adapts Timezone
// for modules that must not import identity.
type Settings interface {
	CreateDefault(ctx context.Context, userID uuid.UUID, timezone string) error
	// Timezone returns the IANA timezone name of the user.
	Timezone(ctx context.Context, userID uuid.UUID) (string, error)
}

// ErrUserNotFound is returned by Users.Get for an unknown user.
var ErrUserNotFound = service.ErrUserNotFound
