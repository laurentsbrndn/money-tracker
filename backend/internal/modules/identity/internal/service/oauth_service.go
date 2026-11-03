package service

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
)

const (
	maxNameLen   = 100
	defaultName  = "Pengguna"
	maxLoginTrys = 2
)

// errRetry asks loginOnce to run again after losing a race on a unique index.
var errRetry = errors.New("retry")

// IDTokenVerifier verifies an Apple or Google ID token.
type IDTokenVerifier interface {
	Verify(ctx context.Context, idToken string) (auth.OIDCIdentity, error)
}

// OAuthInput is the data of an Apple or Google login.
type OAuthInput struct {
	Provider string
	IDToken  string
	// Name is only sent by Apple, and only on the first login.
	Name     string
	Timezone string
	Device   Device
}

// OAuthService logs in or registers users through Apple and Google (docs/BACKEND.md §6.1).
type OAuthService struct {
	db         *database.TxManager
	users      *repository.UserRepository
	identities *repository.AuthIdentityRepository
	views      *UserViewer
	tokens     *TokenService
	onboarder  Onboarder
	clock      clock.Clock
	verifiers  map[string]IDTokenVerifier
}

// NewOAuthService builds the service. verifiers is keyed by provider; a missing provider
// answers ErrOAuthUnavailable (OAuth not configured, local environment only).
func NewOAuthService(
	db *database.TxManager,
	users *repository.UserRepository,
	identities *repository.AuthIdentityRepository,
	views *UserViewer,
	tokens *TokenService,
	onboarder Onboarder,
	clk clock.Clock,
	verifiers map[string]IDTokenVerifier,
) *OAuthService {
	return &OAuthService{
		db: db, users: users, identities: identities, views: views, tokens: tokens,
		onboarder: onboarder, clock: clk, verifiers: verifiers,
	}
}

// Login verifies the ID token and signs the user in:
//
//  1. identity (provider, sub) known → log in that user;
//  2. unknown, provider email verified, and a user with that email is verified → link and log in;
//  3. unknown, but the email belongs to any other account → email_taken;
//  4. otherwise create a new user (verified when the provider says so) and onboard it.
func (s *OAuthService) Login(ctx context.Context, in OAuthInput) (AuthResult, error) {
	verifier := s.verifiers[in.Provider]
	if verifier == nil {
		return AuthResult{}, ErrOAuthUnavailable
	}
	if err := validateTimezone(in.Timezone); err != nil {
		return AuthResult{}, err
	}
	ident, err := verifier.Verify(ctx, in.IDToken)
	if err != nil {
		if errors.Is(err, auth.ErrIDTokenInvalid) {
			return AuthResult{}, ErrIDTokenInvalid
		}
		return AuthResult{}, err
	}

	for range maxLoginTrys {
		result, err := s.loginOnce(ctx, in, ident)
		if errors.Is(err, errRetry) {
			continue
		}
		return result, err
	}
	return AuthResult{}, errors.New("oauth login: too many concurrent attempts")
}

func (s *OAuthService) loginOnce(ctx context.Context, in OAuthInput, ident auth.OIDCIdentity) (AuthResult, error) {
	var user *model.User
	var isNew bool
	var tokens Tokens
	err := s.db.WithTx(ctx, func(ctx context.Context) error {
		var err error
		user, isNew, err = s.resolveUser(ctx, in, ident)
		if err != nil {
			return err
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
	return AuthResult{User: view, Tokens: tokens, IsNewUser: isNew}, nil
}

// resolveUser applies the four rules of Login. It reports whether the user was just created.
func (s *OAuthService) resolveUser(ctx context.Context, in OAuthInput, ident auth.OIDCIdentity) (*model.User, bool, error) {
	linked, err := s.identities.FindBySubject(ctx, in.Provider, ident.Subject)
	if err == nil {
		user, err := s.users.GetByID(ctx, linked.UserID)
		if err != nil {
			return nil, false, mapUserError(err)
		}
		if user.Status != model.UserStatusActive {
			return nil, false, ErrAccountInactive
		}
		return user, false, nil
	}
	if !errors.Is(err, repository.ErrNotFound) {
		return nil, false, err
	}

	email := normalizeEmail(ident.Email)
	if email != "" {
		existing, err := s.users.GetByEmail(ctx, email)
		if err == nil {
			canLink := ident.EmailVerified && existing.EmailVerifiedAt != nil && existing.Status == model.UserStatusActive
			if !canLink {
				return nil, false, ErrEmailTaken
			}
			if err := s.link(ctx, existing.ID, in.Provider, ident, email); err != nil {
				return nil, false, err
			}
			return existing, false, nil
		}
		if !errors.Is(err, repository.ErrNotFound) {
			return nil, false, err
		}
	}

	user, err := s.create(ctx, in, ident, email)
	if err != nil {
		return nil, false, err
	}
	return user, true, nil
}

func (s *OAuthService) create(ctx context.Context, in OAuthInput, ident auth.OIDCIdentity, email string) (*model.User, error) {
	userID, err := idgen.NewV7()
	if err != nil {
		return nil, err
	}
	now := s.clock.Now()
	user := &model.User{
		ID:        userID,
		Name:      displayName(email, in.Name, ident.Name),
		Status:    model.UserStatusActive,
		CreatedAt: now,
		UpdatedAt: now,
	}
	if email != "" {
		user.Email = &email
		if ident.EmailVerified {
			user.EmailVerifiedAt = &now
		}
	}
	if err := s.users.Create(ctx, user); err != nil {
		if errors.Is(err, repository.ErrDuplicate) {
			return nil, errRetry
		}
		return nil, err
	}
	if err := database.LockUser(ctx, s.db.DB(ctx), userID); err != nil {
		return nil, err
	}
	if err := s.onboarder.Onboard(ctx, userID, in.Timezone); err != nil {
		return nil, err
	}
	if err := s.link(ctx, userID, in.Provider, ident, email); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *OAuthService) link(ctx context.Context, userID uuid.UUID, provider string, ident auth.OIDCIdentity, email string) error {
	id, err := idgen.NewV7()
	if err != nil {
		return err
	}
	row := &model.AuthIdentity{
		ID:              id,
		UserID:          userID,
		Provider:        provider,
		ProviderSubject: ident.Subject,
		CreatedAt:       s.clock.Now(),
	}
	if email != "" {
		row.Email = &email
	}
	if err := s.identities.Create(ctx, row); err != nil {
		if errors.Is(err, repository.ErrDuplicate) {
			return errRetry
		}
		return err
	}
	return nil
}

// displayName picks the first non-empty name, then the local part of the email, then a
// generic fallback, cut to the 100 characters users.name allows.
func displayName(email string, candidates ...string) string {
	for _, c := range candidates {
		if c = strings.TrimSpace(c); c != "" {
			return truncateRunes(c, maxNameLen)
		}
	}
	if local, _, ok := strings.Cut(email, "@"); ok && local != "" {
		return truncateRunes(local, maxNameLen)
	}
	return defaultName
}

func truncateRunes(s string, limit int) string {
	if utf8.RuneCountInString(s) <= limit {
		return s
	}
	return string([]rune(s)[:limit])
}
