package auth

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

const (
	appleJWKSURL   = "https://appleid.apple.com/auth/keys"
	appleIssuer    = "https://appleid.apple.com"
	googleJWKSURL  = "https://www.googleapis.com/oauth2/v3/certs"
	googleIssuer1  = "accounts.google.com"
	googleIssuer2  = "https://accounts.google.com"
	oidcSigningAlg = "RS256"
)

// ErrIDTokenInvalid is returned when an Apple or Google ID token fails verification.
var ErrIDTokenInvalid = errors.New("id token invalid")

// OIDCIdentity is the verified identity from an ID token.
type OIDCIdentity struct {
	Subject       string
	Email         string
	EmailVerified bool
	// Name is the display name claim; Google sends it, Apple does not.
	Name string
}

// OIDCVerifier verifies ID tokens (signature via JWKS, iss, aud, exp).
type OIDCVerifier struct {
	keys      keyfunc.Keyfunc
	issuers   []string
	audiences []string
}

// NewOIDCVerifier builds a verifier for the JWKS at jwksURL. Creating it fetches the key set,
// so build it once the module that needs it is wired, not at process start.
func NewOIDCVerifier(ctx context.Context, jwksURL string, issuers, audiences []string) (*OIDCVerifier, error) {
	keys, err := keyfunc.NewDefaultCtx(ctx, []string{jwksURL})
	if err != nil {
		return nil, fmt.Errorf("load jwks %s: %w", jwksURL, err)
	}
	return &OIDCVerifier{keys: keys, issuers: issuers, audiences: audiences}, nil
}

// NewAppleVerifier verifies Sign in with Apple tokens for the given bundle ID.
func NewAppleVerifier(ctx context.Context, bundleID string) (*OIDCVerifier, error) {
	return NewOIDCVerifier(ctx, appleJWKSURL, []string{appleIssuer}, []string{bundleID})
}

// NewGoogleVerifier verifies Google ID tokens issued for any of clientIDs.
func NewGoogleVerifier(ctx context.Context, clientIDs []string) (*OIDCVerifier, error) {
	return NewOIDCVerifier(ctx, googleJWKSURL, []string{googleIssuer1, googleIssuer2}, clientIDs)
}

// Verify validates idToken and returns the identity it carries.
func (v *OIDCVerifier) Verify(ctx context.Context, idToken string) (OIDCIdentity, error) {
	claims := jwt.MapClaims{}
	_, err := jwt.ParseWithClaims(idToken, claims, v.keys.KeyfuncCtx(ctx),
		jwt.WithValidMethods([]string{oidcSigningAlg}),
		jwt.WithExpirationRequired(),
	)
	if err != nil {
		return OIDCIdentity{}, fmt.Errorf("%w: %w", ErrIDTokenInvalid, err)
	}

	issuer, err := claims.GetIssuer()
	if err != nil || !slices.Contains(v.issuers, issuer) {
		return OIDCIdentity{}, fmt.Errorf("%w: unexpected issuer", ErrIDTokenInvalid)
	}
	audience, err := claims.GetAudience()
	if err != nil || !slices.ContainsFunc(audience, func(a string) bool { return slices.Contains(v.audiences, a) }) {
		return OIDCIdentity{}, fmt.Errorf("%w: unexpected audience", ErrIDTokenInvalid)
	}
	subject, err := claims.GetSubject()
	if err != nil || subject == "" {
		return OIDCIdentity{}, fmt.Errorf("%w: missing subject", ErrIDTokenInvalid)
	}

	email, _ := claims["email"].(string)
	name, _ := claims["name"].(string)
	return OIDCIdentity{
		Subject:       subject,
		Email:         email,
		EmailVerified: claimBool(claims["email_verified"]),
		Name:          name,
	}, nil
}

// claimBool reads a boolean claim; Apple sends email_verified as the string "true".
func claimBool(v any) bool {
	switch b := v.(type) {
	case bool:
		return b
	case string:
		return strings.EqualFold(b, "true")
	default:
		return false
	}
}
