package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"moneytracker/internal/platform/clock"
)

// AccessAudience is the aud claim of access tokens.
const AccessAudience = "moneytracker-app"

var (
	// ErrTokenExpired is returned by Verify for a validly signed but expired token.
	ErrTokenExpired = errors.New("access token expired")
	// ErrTokenInvalid is returned by Verify for any other verification failure.
	ErrTokenInvalid = errors.New("access token invalid")
)

// Claims are the verified contents of an access token.
type Claims struct {
	UserID    uuid.UUID
	SessionID uuid.UUID // refresh-token family ID (claim sid)
	ExpiresAt time.Time
}

type accessClaims struct {
	SessionID string `json:"sid"`
	jwt.RegisteredClaims
}

// JWT issues and verifies HS256 access tokens.
type JWT struct {
	secret []byte
	issuer string
	ttl    time.Duration
	clock  clock.Clock
}

// NewJWT builds a token issuer/verifier.
func NewJWT(secret, issuer string, ttl time.Duration, clk clock.Clock) *JWT {
	return &JWT{secret: []byte(secret), issuer: issuer, ttl: ttl, clock: clk}
}

// Issue signs an access token for userID within the session familyID.
func (j *JWT) Issue(userID, familyID uuid.UUID) (string, time.Time, error) {
	now := j.clock.Now()
	expiresAt := now.Add(j.ttl)
	claims := accessClaims{
		SessionID: familyID.String(),
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			Issuer:    j.issuer,
			Audience:  jwt.ClaimStrings{AccessAudience},
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(j.secret)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("sign access token: %w", err)
	}
	return signed, expiresAt, nil
}

// Verify checks signature, issuer, audience and expiry.
func (j *JWT) Verify(token string) (Claims, error) {
	var claims accessClaims
	_, err := jwt.ParseWithClaims(token, &claims,
		func(*jwt.Token) (any, error) { return j.secret, nil },
		jwt.WithValidMethods([]string{jwt.SigningMethodHS256.Alg()}),
		jwt.WithIssuer(j.issuer),
		jwt.WithAudience(AccessAudience),
		jwt.WithExpirationRequired(),
		jwt.WithTimeFunc(j.clock.Now),
	)
	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return Claims{}, ErrTokenExpired
		}
		return Claims{}, fmt.Errorf("%w: %w", ErrTokenInvalid, err)
	}

	userID, err := uuid.Parse(claims.Subject)
	if err != nil {
		return Claims{}, fmt.Errorf("%w: bad subject", ErrTokenInvalid)
	}
	sessionID, err := uuid.Parse(claims.SessionID)
	if err != nil {
		return Claims{}, fmt.Errorf("%w: bad session", ErrTokenInvalid)
	}
	return Claims{UserID: userID, SessionID: sessionID, ExpiresAt: claims.ExpiresAt.Time}, nil
}
