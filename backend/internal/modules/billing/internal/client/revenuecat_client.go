// Package client talks to the RevenueCat REST API v1.
package client

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// DefaultBaseURL is the RevenueCat REST API origin.
const DefaultBaseURL = "https://api.revenuecat.com"

const (
	requestTimeout = 5 * time.Second
	maxBodyBytes   = 1 << 20
)

// ErrNotConfigured is returned when no secret API key was given.
var ErrNotConfigured = errors.New("revenuecat api key is not configured")

// Entitlement is subscriber.entitlements.<id>. Expired entitlements stay listed with a past
// ExpiresDate; a nil ExpiresDate does not expire.
type Entitlement struct {
	ExpiresDate            *time.Time `json:"expires_date"`
	GracePeriodExpiresDate *time.Time `json:"grace_period_expires_date"`
	ProductIdentifier      string     `json:"product_identifier"`
	PurchaseDate           *time.Time `json:"purchase_date"`
}

// Subscription is subscriber.subscriptions.<product>.
type Subscription struct {
	BillingIssuesDetectedAt *time.Time `json:"billing_issues_detected_at"`
	ExpiresDate             *time.Time `json:"expires_date"`
	GracePeriodExpiresDate  *time.Time `json:"grace_period_expires_date"`
	IsSandbox               bool       `json:"is_sandbox"`
	OriginalPurchaseDate    *time.Time `json:"original_purchase_date"`
	PeriodType              string     `json:"period_type"`
	PurchaseDate            *time.Time `json:"purchase_date"`
	RefundedAt              *time.Time `json:"refunded_at"`
	Store                   string     `json:"store"`
	StoreTransactionID      flexString `json:"store_transaction_id"`
	UnsubscribeDetectedAt   *time.Time `json:"unsubscribe_detected_at"`
}

// Subscriber is the part of the subscriber the app needs.
type Subscriber struct {
	Entitlements  map[string]Entitlement  `json:"entitlements"`
	Subscriptions map[string]Subscription `json:"subscriptions"`
}

// flexString reads a JSON string or number as text (RevenueCat sends both for transaction ids).
type flexString string

func (f *flexString) UnmarshalJSON(b []byte) error {
	s := strings.TrimSpace(string(b))
	if s == "null" {
		*f = ""
		return nil
	}
	if strings.HasPrefix(s, `"`) {
		var v string
		if err := json.Unmarshal(b, &v); err != nil {
			return err
		}
		*f = flexString(v)
		return nil
	}
	*f = flexString(s)
	return nil
}

// String returns the text value.
func (f flexString) String() string { return string(f) }

// RevenueCat is the REST client. Its zero value is unusable; build it with New.
type RevenueCat struct {
	baseURL string
	apiKey  string
	http    *http.Client
}

// New builds the client. An empty apiKey yields a client whose calls fail with ErrNotConfigured.
func New(baseURL, apiKey string) *RevenueCat {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = DefaultBaseURL
	}
	return &RevenueCat{
		baseURL: strings.TrimRight(baseURL, "/"),
		apiKey:  apiKey,
		http:    &http.Client{Timeout: requestTimeout},
	}
}

// Configured reports whether an API key is set.
func (c *RevenueCat) Configured() bool { return c != nil && c.apiKey != "" }

// GetSubscriber reads the current state of the subscriber `GET /v1/subscribers/{app_user_id}`
// (the source of truth after a webhook: webhooks can arrive late, twice, or out of order).
func (c *RevenueCat) GetSubscriber(ctx context.Context, appUserID string) (Subscriber, error) {
	if !c.Configured() {
		return Subscriber{}, ErrNotConfigured
	}
	// The deadline covers connecting, the request and reading the body. The caller holds a
	// database transaction while waiting, so the wait must be short and must end the request.
	ctx, cancel := context.WithTimeout(ctx, requestTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/v1/subscribers/"+url.PathEscape(appUserID), nil)
	if err != nil {
		return Subscriber{}, fmt.Errorf("build revenuecat request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return Subscriber{}, fmt.Errorf("call revenuecat: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyBytes))
	if err != nil {
		return Subscriber{}, fmt.Errorf("read revenuecat response: %w", err)
	}
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return Subscriber{}, fmt.Errorf("revenuecat answered %d", resp.StatusCode)
	}
	var out struct {
		Subscriber Subscriber `json:"subscriber"`
	}
	if err := json.Unmarshal(body, &out); err != nil {
		return Subscriber{}, fmt.Errorf("decode revenuecat response: %w", err)
	}
	return out.Subscriber, nil
}
