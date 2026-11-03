package identity

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/handler"
	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/modules/identity/internal/service"
	"moneytracker/internal/modules/identity/internal/synchandler"
	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/mailer"
	"moneytracker/internal/platform/syncbase"
)

// Deps are the dependencies of the identity module.
type Deps struct {
	DB           *database.TxManager
	Clock        clock.Clock
	JWT          *auth.JWT
	OTP          *auth.OTP
	Mailer       mailer.Mailer
	Onboarder    Onboarder
	Entitlements EntitlementReader
	// AppleVerifier and GoogleVerifier may be nil (local environment without OAuth config):
	// the matching endpoint then answers "OAuth belum dikonfigurasi". Leave them as nil
	// interfaces, not typed nil pointers.
	AppleVerifier   IDTokenVerifier
	GoogleVerifier  IDTokenVerifier
	RefreshTokenTTL time.Duration
	Log             *slog.Logger
}

// Module wires identity's repositories, services, and handlers.
type Module struct {
	db           *database.TxManager
	users        *repository.UserRepository
	settings     *repository.UserSettingsRepository
	refresh      *repository.RefreshTokenRepository
	verification *repository.VerificationTokenRepository
	settingsSvc  *service.UserSettingsService
	settingsSync syncbase.Handler
	views        *service.UserViewer
	authHandler  *handler.AuthHandler
	meHandler    *handler.MeHandler
}

// New builds the module.
func New(d Deps) *Module {
	users := repository.NewUserRepository(d.DB)
	identities := repository.NewAuthIdentityRepository(d.DB)
	refresh := repository.NewRefreshTokenRepository(d.DB)
	verifications := repository.NewVerificationTokenRepository(d.DB)
	settings := repository.NewUserSettingsRepository(d.DB)

	views := service.NewUserViewer(identities)
	tokens := service.NewTokenService(d.DB, users, refresh, d.JWT, d.Clock, d.RefreshTokenTTL)
	verification := service.NewVerificationService(d.DB, users, verifications, refresh, views, d.OTP, d.Mailer, d.Clock, d.Log)
	authService := service.NewAuthService(d.DB, users, views, tokens, verification, d.Onboarder, d.Clock)
	settingsSvc := service.NewUserSettingsService(settings, d.Clock)
	verifiers := map[string]service.IDTokenVerifier{}
	if d.AppleVerifier != nil {
		verifiers[model.ProviderApple] = d.AppleVerifier
	}
	if d.GoogleVerifier != nil {
		verifiers[model.ProviderGoogle] = d.GoogleVerifier
	}
	oauth := service.NewOAuthService(d.DB, users, identities, views, tokens, d.Onboarder, d.Clock, verifiers)
	account := service.NewAccountService(d.DB, users, refresh, views, d.Entitlements, d.Clock)

	return &Module{
		db:           d.DB,
		users:        users,
		settings:     settings,
		refresh:      refresh,
		verification: verifications,
		settingsSvc:  settingsSvc,
		settingsSync: synchandler.NewUserSettingsHandler(settings, settingsSvc),
		views:        views,
		authHandler:  handler.NewAuthHandler(authService, oauth, tokens, verification, account),
		meHandler:    handler.NewMeHandler(account),
	}
}

// API returns the public interface of the module.
func (m *Module) API() Users {
	return usersAPI{users: m.users, views: m.views}
}

// Settings returns the interface the Onboarder uses to create a new user's settings row.
func (m *Module) Settings() Settings {
	return m.settingsSvc
}

// RegisterSyncHandlers registers the user_settings sync handler.
func (m *Module) RegisterSyncHandlers(r syncbase.Registry) {
	r.Register(m.settingsSync)
}

// RegisterRoutes mounts the identity routes. public is the /v1/auth group (no auth guard
// there); protected is the /v1 group, whose guard is applied globally. Auth endpoints that
// need a logged-in user carry authGuard themselves.
func (m *Module) RegisterRoutes(public, protected fiber.Router, authGuard fiber.Handler) {
	public.Post("/register", m.authHandler.Register)
	public.Post("/login", m.authHandler.Login)
	public.Post("/oauth/apple", m.authHandler.LoginWithApple)
	public.Post("/oauth/google", m.authHandler.LoginWithGoogle)
	public.Post("/refresh", m.authHandler.Refresh)
	public.Post("/logout", m.authHandler.Logout)
	public.Post("/password/forgot", m.authHandler.ForgotPassword)
	public.Post("/password/reset", m.authHandler.ResetPassword)
	public.Post("/email/verification", authGuard, m.authHandler.ResendVerification)
	public.Post("/email/verify", authGuard, m.authHandler.VerifyEmail)
	public.Post("/password/change", authGuard, m.authHandler.ChangePassword)

	protected.Get("/me", m.meHandler.Get)
	protected.Patch("/me", m.meHandler.Update)
	protected.Delete("/me", m.meHandler.Delete)
}

// DeleteExpiredTokens removes refresh tokens and verification codes that expired before cutoff
// (maintenance job, docs/API.md §7). It returns how many of each were removed.
func (m *Module) DeleteExpiredTokens(ctx context.Context, cutoff time.Time) (refreshTokens, verificationTokens int64, err error) {
	refreshTokens, err = m.refresh.DeleteExpiredBefore(ctx, cutoff)
	if err != nil {
		return 0, 0, err
	}
	verificationTokens, err = m.verification.DeleteExpiredBefore(ctx, cutoff)
	if err != nil {
		return refreshTokens, 0, err
	}
	return refreshTokens, verificationTokens, nil
}

// PendingDeletion lists the users whose deletion was requested before cutoff and are still in
// pending_deletion, oldest first, at most limit (maintenance job).
func (m *Module) PendingDeletion(ctx context.Context, cutoff time.Time, limit int) ([]uuid.UUID, error) {
	return m.users.PendingDeletionBefore(ctx, cutoff, limit)
}

// PurgeUser permanently deletes the user, its sessions and codes (ON DELETE CASCADE), and the
// settings row, which is a [sync] row and therefore written under the user lock.
func (m *Module) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, m.db.DB(ctx), userID); err != nil {
			return err
		}
		if err := m.settings.DeleteByUser(ctx, userID); err != nil {
			return err
		}
		return m.users.Delete(ctx, userID)
	})
}

type usersAPI struct {
	users *repository.UserRepository
	views *service.UserViewer
}

func (a usersAPI) Get(ctx context.Context, userID uuid.UUID) (User, error) {
	u, err := a.users.GetByID(ctx, userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return User{}, fmt.Errorf("get user %s: %w", userID, ErrUserNotFound)
		}
		return User{}, err
	}
	v, err := a.views.View(ctx, u)
	if err != nil {
		return User{}, err
	}
	return User{
		ID: v.ID, Name: v.Name, Email: v.Email,
		EmailVerified: v.EmailVerified, HasPassword: v.HasPassword, Providers: v.Providers,
	}, nil
}
