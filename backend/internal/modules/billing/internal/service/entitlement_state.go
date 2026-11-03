package service

import (
	"strings"
	"time"

	"moneytracker/internal/modules/billing/internal/client"
	"moneytracker/internal/modules/billing/internal/dto"
	"moneytracker/internal/modules/billing/internal/model"
)

// State is the entitlement of one user plus the subscription behind it, as derived from
// RevenueCat. It is pure data: deriving it needs no database.
type State struct {
	// Premium says whether access is granted right now.
	Premium bool
	// AccessEnd is when access ends (the grace period end while in grace); nil does not expire.
	AccessEnd *time.Time

	// HasSubscription is false for an entitlement without a store subscription of ours
	// (promotional grants, other stores); the fields below are then unset.
	HasSubscription bool
	Store           string
	ProductID       string
	PeriodType      string
	PeriodStart     time.Time
	PeriodEnd       time.Time
	Status          string
	WillRenew       bool
	Environment     string
	// OriginalTransactionID is empty until the service resolves it (see resolveOriginal).
	OriginalTransactionID string
	// StoreTransactionID is the latest store transaction, the fallback original id.
	StoreTransactionID string
}

// RevenueCat event types (docs: RevenueCat webhooks, event types and fields).
const (
	evTest                  = "TEST"
	evInitialPurchase       = "INITIAL_PURCHASE"
	evRenewal               = "RENEWAL"
	evCancellation          = "CANCELLATION"
	evUncancellation        = "UNCANCELLATION"
	evNonRenewingPurchase   = "NON_RENEWING_PURCHASE"
	evSubscriptionPaused    = "SUBSCRIPTION_PAUSED"
	evExpiration            = "EXPIRATION"
	evBillingIssue          = "BILLING_ISSUE"
	evProductChange         = "PRODUCT_CHANGE"
	evSubscriptionExtended  = "SUBSCRIPTION_EXTENDED"
	evRefundReversed        = "REFUND_REVERSED"
	evTransfer              = "TRANSFER"
	evTemporaryGrant        = "TEMPORARY_ENTITLEMENT_GRANT"
	evPurchaseRedeemed      = "PURCHASE_REDEEMED"
	cancelCustomerSupport   = "CUSTOMER_SUPPORT"
	cancelBillingError      = "BILLING_ERROR"
	temporaryGrantDuration  = 24 * time.Hour
	entitlementKeyInPayload = model.EntitlementPremium
)

// stateEventTypes are the events whose own fields describe the subscription state. A newer
// handled event of these types makes an older one obsolete (see WebhookService).
var stateEventTypes = []string{
	evInitialPurchase, evRenewal, evCancellation, evUncancellation, evNonRenewingPurchase,
	evSubscriptionPaused, evExpiration, evBillingIssue, evProductChange, evSubscriptionExtended,
	evRefundReversed, evTemporaryGrant,
}

// ignoredEvent reports whether the event type never changes an entitlement.
func ignoredEvent(t string) bool {
	switch t {
	case evTest, "EXPERIMENT_ENROLLMENT", "VIRTUAL_CURRENCY_TRANSACTION", "INVOICE_ISSUANCE",
		"SUBSCRIBER_ALIAS", "PRICE_INCREASE_CONSENT_REQUIRED", "PRICE_INCREASE_CONSENT_APPROVED":
		return true
	}
	return false
}

// normalizeStore maps a RevenueCat store name (upper case in webhooks, lower case in the REST
// API) to ours. Stores we have no subscription model for return "".
func normalizeStore(s string) string {
	switch strings.ToLower(s) {
	case "app_store", "mac_app_store":
		return model.StoreAppStore
	case "play_store":
		return model.StorePlayStore
	}
	return ""
}

func normalizePeriod(s string) string {
	switch strings.ToLower(s) {
	case "trial":
		return model.PeriodTrial
	case "intro":
		return model.PeriodIntro
	}
	return model.PeriodNormal
}

func normalizeEnv(sandbox bool) string {
	if sandbox {
		return model.EnvSandbox
	}
	return model.EnvProduction
}

func normalizeEnvName(s string) string {
	if strings.EqualFold(s, "SANDBOX") {
		return model.EnvSandbox
	}
	return model.EnvProduction
}

// accessActive reports whether access lasting until end is still granted at now.
func accessActive(end *time.Time, now time.Time) bool {
	return end == nil || end.After(now)
}

func laterOf(a, b *time.Time) *time.Time {
	switch {
	case a == nil:
		return b
	case b == nil:
		return a
	case b.After(*a):
		return b
	}
	return a
}

// StateFromSubscriber derives the state from the RevenueCat subscriber (the source of truth).
//
// The entitlement is active while now is before its expiry, or before the grace period end
// when the store is retrying a failed payment. A refund ends access at once. Expired
// entitlements stay listed by RevenueCat, so the dates decide, not the presence of the key.
func StateFromSubscriber(sub client.Subscriber, now time.Time) State {
	ent, ok := sub.Entitlements[entitlementKeyInPayload]
	if !ok {
		return State{}
	}
	rc, hasRC := sub.Subscriptions[ent.ProductIdentifier]

	end := ent.ExpiresDate
	if ent.ExpiresDate != nil {
		end = laterOf(ent.ExpiresDate, ent.GracePeriodExpiresDate)
	}
	st := State{Premium: accessActive(end, now), AccessEnd: end}

	store := ""
	if hasRC {
		store = normalizeStore(rc.Store)
	}
	if !hasRC || store == "" {
		if hasRC && rc.RefundedAt != nil {
			st.Premium = false
		}
		return st
	}

	periodEnd := now
	switch {
	case rc.ExpiresDate != nil:
		periodEnd = *rc.ExpiresDate
	case end != nil:
		periodEnd = *end
	}
	periodStart := periodEnd
	if rc.PurchaseDate != nil {
		periodStart = *rc.PurchaseDate
	}

	st.HasSubscription = true
	st.Store = store
	st.ProductID = ent.ProductIdentifier
	st.PeriodType = normalizePeriod(rc.PeriodType)
	st.PeriodStart = periodStart
	st.PeriodEnd = periodEnd
	st.Environment = normalizeEnv(rc.IsSandbox)
	st.StoreTransactionID = rc.StoreTransactionID.String()

	expired := !periodEnd.After(now)
	graceActive := rc.GracePeriodExpiresDate != nil && rc.GracePeriodExpiresDate.After(now) && expired
	switch {
	case rc.RefundedAt != nil:
		st.Status = model.StatusRefunded
		st.Premium = false
		refunded := *rc.RefundedAt
		if st.AccessEnd == nil || refunded.Before(*st.AccessEnd) {
			st.AccessEnd = &refunded
		}
	case graceActive:
		st.Status = model.StatusInGracePeriod
		st.WillRenew = true
	case expired && rc.BillingIssuesDetectedAt != nil:
		st.Status = model.StatusInBillingRetry
		st.WillRenew = true
	case expired:
		st.Status = model.StatusExpired
	case rc.BillingIssuesDetectedAt != nil:
		st.Status = model.StatusInBillingRetry
		st.WillRenew = true
	case rc.UnsubscribeDetectedAt != nil:
		st.Status = model.StatusCancelled
	default:
		st.Status = model.StatusActive
		st.WillRenew = true
	}
	return st
}

// StateFromEvent derives the state from the fields of one webhook event. It is the fallback
// when the REST API cannot be reached; ok is false for events that carry no usable state.
func StateFromEvent(ev dto.RevenueCatEvent, now time.Time) (State, bool) {
	var end *time.Time
	if ev.ExpirationAtMs != nil {
		t := time.UnixMilli(*ev.ExpirationAtMs).UTC()
		end = &t
	}
	start := now
	if ev.PurchasedAtMs != nil {
		start = time.UnixMilli(*ev.PurchasedAtMs).UTC()
	}
	product := ev.ProductID
	if ev.Type == evProductChange && ev.NewProductID != "" {
		product = ev.NewProductID
	}
	store := normalizeStore(ev.Store)

	st := State{AccessEnd: end, PeriodStart: start, PeriodEnd: now, Environment: normalizeEnvName(ev.Environment)}
	if end != nil {
		st.PeriodEnd = *end
	}
	if store != "" && product != "" && ev.OriginalTransaction != "" {
		st.HasSubscription = true
		st.Store = store
		st.ProductID = product
		st.PeriodType = normalizePeriod(ev.PeriodType)
		st.OriginalTransactionID = ev.OriginalTransaction
		st.StoreTransactionID = ev.TransactionID
	}

	switch ev.Type {
	case evInitialPurchase, evRenewal, evUncancellation, evRefundReversed, evSubscriptionExtended, evProductChange:
		st.Premium = accessActive(end, now)
		st.Status = model.StatusActive
		st.WillRenew = true
	case evNonRenewingPurchase:
		st.Premium = accessActive(end, now)
		st.Status = model.StatusActive
	case evSubscriptionPaused:
		// Access is not revoked until the EXPIRATION with reason SUBSCRIPTION_PAUSED.
		st.Premium = accessActive(end, now)
		st.Status = model.StatusCancelled
	case evCancellation:
		switch ev.CancelReason {
		case cancelCustomerSupport:
			st.Status = model.StatusRefunded
			st.Premium = false
			at := time.UnixMilli(*ev.EventTimestampMs).UTC()
			if end == nil || at.Before(*end) {
				st.AccessEnd = &at
			}
		case cancelBillingError:
			st.Status = model.StatusInBillingRetry
			st.WillRenew = true
			st.Premium = accessActive(end, now)
		default:
			st.Status = model.StatusCancelled
			st.Premium = accessActive(end, now)
		}
	case evBillingIssue:
		st.WillRenew = true
		var grace *time.Time
		if ev.GraceExpirationAtMs != nil {
			t := time.UnixMilli(*ev.GraceExpirationAtMs).UTC()
			grace = &t
		}
		if grace != nil && grace.After(now) {
			st.Status = model.StatusInGracePeriod
			st.AccessEnd = laterOf(end, grace)
			st.Premium = true
		} else {
			st.Status = model.StatusInBillingRetry
			st.Premium = accessActive(end, now)
		}
	case evExpiration:
		st.Status = model.StatusExpired
		st.Premium = false
	case evTemporaryGrant:
		until := now.Add(temporaryGrantDuration)
		return State{Premium: true, AccessEnd: &until}, true
	default:
		return State{}, false
	}
	return st, true
}
