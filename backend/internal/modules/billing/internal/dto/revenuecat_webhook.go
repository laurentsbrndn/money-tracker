// Package dto holds the HTTP payloads of the billing module.
package dto

// RevenueCatEvent is the `event` of a RevenueCat webhook. Only the fields billing reads are
// declared; unknown fields are ignored, as RevenueCat documents that new ones may appear.
type RevenueCatEvent struct {
	ID                  string   `json:"id" validate:"required,max=100"`
	Type                string   `json:"type" validate:"required,max=50"`
	EventTimestampMs    *int64   `json:"event_timestamp_ms" validate:"required"`
	AppUserID           string   `json:"app_user_id"`
	OriginalAppUserID   string   `json:"original_app_user_id"`
	Aliases             []string `json:"aliases"`
	ProductID           string   `json:"product_id"`
	NewProductID        string   `json:"new_product_id"`
	PeriodType          string   `json:"period_type"`
	Store               string   `json:"store"`
	Environment         string   `json:"environment"`
	TransactionID       string   `json:"transaction_id"`
	OriginalTransaction string   `json:"original_transaction_id"`
	CancelReason        string   `json:"cancel_reason"`
	ExpirationReason    string   `json:"expiration_reason"`
	EntitlementIDs      []string `json:"entitlement_ids"`
	PurchasedAtMs       *int64   `json:"purchased_at_ms"`
	ExpirationAtMs      *int64   `json:"expiration_at_ms"`
	GraceExpirationAtMs *int64   `json:"grace_period_expiration_at_ms"`
	TransferredFrom     []string `json:"transferred_from"`
	TransferredTo       []string `json:"transferred_to"`
	RedeemedFrom        []string `json:"redeemed_from"`
	RedeemedBy          []string `json:"redeemed_by"`
}

// RevenueCatWebhook is the body of POST /v1/billing/webhooks/revenuecat.
type RevenueCatWebhook struct {
	APIVersion string          `json:"api_version"`
	Event      RevenueCatEvent `json:"event" validate:"required"`
}
