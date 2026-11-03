package auth

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"
)

// jwksLoadTimeout bounds the first JWKS download so a slow Apple/Google endpoint cannot hang
// a login request.
const jwksLoadTimeout = 10 * time.Second

// LazyOIDCVerifier builds its OIDCVerifier on first use, so process start (and every
// serverless cold start) does not depend on Apple or Google being reachable. A failed build
// is not cached: the next call tries again.
type LazyOIDCVerifier struct {
	base    context.Context
	factory func(ctx context.Context) (*OIDCVerifier, error)

	mu       sync.Mutex
	verifier *OIDCVerifier
	// stop ends the key refresh goroutine of verifier.
	stop context.CancelFunc
}

// NewLazyOIDCVerifier wraps factory. base must outlive requests: the key set refreshes in a
// goroutine that ends when base is cancelled.
func NewLazyOIDCVerifier(base context.Context, factory func(ctx context.Context) (*OIDCVerifier, error)) *LazyOIDCVerifier {
	return &LazyOIDCVerifier{base: base, factory: factory}
}

// Verify validates idToken, building the underlying verifier first if needed.
func (l *LazyOIDCVerifier) Verify(ctx context.Context, idToken string) (OIDCIdentity, error) {
	v, err := l.get(ctx)
	if err != nil {
		return OIDCIdentity{}, err
	}
	return v.Verify(ctx, idToken)
}

func (l *LazyOIDCVerifier) get(ctx context.Context) (*OIDCVerifier, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.verifier != nil {
		return l.verifier, nil
	}

	buildCtx, cancel := context.WithCancel(l.base)
	type result struct {
		v   *OIDCVerifier
		err error
	}
	done := make(chan result, 1)
	go func() {
		v, err := l.factory(buildCtx)
		done <- result{v, err}
	}()

	select {
	case r := <-done:
		if r.err != nil {
			cancel()
			return nil, fmt.Errorf("build oidc verifier: %w", r.err)
		}
		l.verifier, l.stop = r.v, cancel
		return l.verifier, nil
	case <-time.After(jwksLoadTimeout):
		cancel()
		return nil, errors.New("build oidc verifier: timed out loading jwks")
	case <-ctx.Done():
		cancel()
		return nil, fmt.Errorf("build oidc verifier: %w", ctx.Err())
	}
}
