package middleware

import (
	"crypto/subtle"
	"errors"
	"strings"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/auth"
	"moneytracker/internal/platform/httpx"
)

// AccessTokenVerifier verifies access tokens; implemented by auth.JWT.
type AccessTokenVerifier interface {
	Verify(token string) (auth.Claims, error)
}

// Auth verifies the Bearer access token and stores the user ID and session ID in locals.
// Expired tokens yield token_expired (the app refreshes); anything else yields unauthorized.
func Auth(verifier AccessTokenVerifier) fiber.Handler {
	return func(c fiber.Ctx) error {
		token, ok := bearerToken(c)
		if !ok {
			return httpx.Unauthorized("Token tidak ada")
		}
		claims, err := verifier.Verify(token)
		if err != nil {
			if errors.Is(err, auth.ErrTokenExpired) {
				return httpx.New(fiber.StatusUnauthorized, httpx.CodeTokenExpired, "Token kedaluwarsa")
			}
			return httpx.Unauthorized("Token tidak valid")
		}
		c.Locals(httpx.LocalUserID, claims.UserID)
		c.Locals(httpx.LocalSessionID, claims.SessionID)
		return c.Next()
	}
}

// bearerToken extracts the token from "Authorization: Bearer <token>".
func bearerToken(c fiber.Ctx) (string, bool) {
	header := c.Get(fiber.HeaderAuthorization)
	const prefix = "bearer "
	if len(header) <= len(prefix) || !strings.EqualFold(header[:len(prefix)], prefix) {
		return "", false
	}
	token := strings.TrimSpace(header[len(prefix):])
	return token, token != ""
}

// requireBearerSecret accepts only requests whose Bearer token equals secret.
// An empty secret rejects everything, so a misconfigured deployment fails closed.
func requireBearerSecret(secret string) fiber.Handler {
	want := []byte(secret)
	return func(c fiber.Ctx) error {
		token, ok := bearerToken(c)
		if !ok || len(want) == 0 || subtle.ConstantTimeCompare([]byte(token), want) != 1 {
			return httpx.Unauthorized("Token tidak valid")
		}
		return c.Next()
	}
}
