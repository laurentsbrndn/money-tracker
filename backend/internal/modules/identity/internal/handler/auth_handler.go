package handler

import (
	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/identity/internal/dto"
	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/service"
	"moneytracker/internal/platform/httpx"
)

// AuthHandler serves /v1/auth/*.
type AuthHandler struct {
	auth         *service.AuthService
	oauth        *service.OAuthService
	tokens       *service.TokenService
	verification *service.VerificationService
	account      *service.AccountService
}

// NewAuthHandler builds the handler.
func NewAuthHandler(
	auth *service.AuthService,
	oauth *service.OAuthService,
	tokens *service.TokenService,
	verification *service.VerificationService,
	account *service.AccountService,
) *AuthHandler {
	return &AuthHandler{auth: auth, oauth: oauth, tokens: tokens, verification: verification, account: account}
}

// Register handles POST /v1/auth/register.
func (h *AuthHandler) Register(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.RegisterRequest](c)
	if err != nil {
		return err
	}
	result, err := h.auth.Register(c.Context(), service.RegisterInput{
		Name: req.Name, Email: req.Email, Password: req.Password, Timezone: req.Timezone,
		Device: deviceOf(c),
	})
	if err != nil {
		return mapError(err)
	}
	return httpx.Created(c, dto.NewAuthResponse(result))
}

// Login handles POST /v1/auth/login.
func (h *AuthHandler) Login(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.LoginRequest](c)
	if err != nil {
		return err
	}
	result, err := h.auth.Login(c.Context(), service.LoginInput{
		Email: req.Email, Password: req.Password, Device: deviceOf(c),
	})
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.NewAuthResponse(result))
}

// LoginWithApple handles POST /v1/auth/oauth/apple.
func (h *AuthHandler) LoginWithApple(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.AppleLoginRequest](c)
	if err != nil {
		return err
	}
	result, err := h.oauth.Login(c.Context(), service.OAuthInput{
		Provider: model.ProviderApple, IDToken: req.IdentityToken, Name: req.Name,
		Timezone: req.Timezone, Device: deviceOf(c),
	})
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.NewAuthResponse(result))
}

// LoginWithGoogle handles POST /v1/auth/oauth/google.
func (h *AuthHandler) LoginWithGoogle(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.GoogleLoginRequest](c)
	if err != nil {
		return err
	}
	result, err := h.oauth.Login(c.Context(), service.OAuthInput{
		Provider: model.ProviderGoogle, IDToken: req.IDToken,
		Timezone: req.Timezone, Device: deviceOf(c),
	})
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.NewAuthResponse(result))
}

// Refresh handles POST /v1/auth/refresh.
func (h *AuthHandler) Refresh(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.RefreshRequest](c)
	if err != nil {
		return err
	}
	tokens, err := h.tokens.Refresh(c.Context(), req.RefreshToken, deviceOf(c))
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.RefreshResponse{Tokens: dto.NewTokens(tokens)})
}

// Logout handles POST /v1/auth/logout. It is public: the refresh token in the body is the
// credential, because the access token may already have expired. Unknown tokens answer 204.
func (h *AuthHandler) Logout(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.RefreshRequest](c)
	if err != nil {
		return err
	}
	if err := h.tokens.Logout(c.Context(), req.RefreshToken); err != nil {
		return mapError(err)
	}
	return httpx.NoContent(c)
}

// ResendVerification handles POST /v1/auth/email/verification.
func (h *AuthHandler) ResendVerification(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	if err := h.verification.ResendEmailVerification(c.Context(), userID); err != nil {
		return mapError(err)
	}
	return httpx.Accepted(c)
}

// VerifyEmail handles POST /v1/auth/email/verify.
func (h *AuthHandler) VerifyEmail(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	req, err := httpx.BindAndValidate[dto.VerifyEmailRequest](c)
	if err != nil {
		return err
	}
	user, err := h.verification.VerifyEmail(c.Context(), userID, req.Code)
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.UserEnvelope{User: dto.NewUser(user)})
}

// ForgotPassword handles POST /v1/auth/password/forgot. It always answers 202.
func (h *AuthHandler) ForgotPassword(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.ForgotPasswordRequest](c)
	if err != nil {
		return err
	}
	if err := h.verification.ForgotPassword(c.Context(), req.Email); err != nil {
		return mapError(err)
	}
	return httpx.Accepted(c)
}

// ResetPassword handles POST /v1/auth/password/reset.
func (h *AuthHandler) ResetPassword(c fiber.Ctx) error {
	req, err := httpx.BindAndValidate[dto.ResetPasswordRequest](c)
	if err != nil {
		return err
	}
	if err := h.verification.ResetPassword(c.Context(), req.Email, req.Code, req.NewPassword); err != nil {
		return mapError(err)
	}
	return httpx.NoContent(c)
}

// ChangePassword handles POST /v1/auth/password/change.
func (h *AuthHandler) ChangePassword(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	sessionID, sessionOK := httpx.SessionID(c)
	if !ok || !sessionOK {
		return httpx.Unauthorized("Token tidak ada")
	}
	req, err := httpx.BindAndValidate[dto.ChangePasswordRequest](c)
	if err != nil {
		return err
	}
	if err := h.account.ChangePassword(c.Context(), userID, sessionID, req.CurrentPassword, req.NewPassword); err != nil {
		return mapError(err)
	}
	return httpx.NoContent(c)
}

// deviceOf reads the app identity (client_info middleware) and the client IP. The IP comes
// from Fiber's proxy-aware c.IP() and is kept for session audit only.
func deviceOf(c fiber.Ctx) service.Device {
	info, _ := httpx.Client(c)
	return service.Device{ID: info.DeviceID, Name: info.DeviceName, IP: c.IP()}
}
