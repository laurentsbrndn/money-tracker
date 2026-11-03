package dto

import "github.com/google/uuid"

// PullChange is one changed row. Data is the whole row without user_id, server_version and
// server_updated_at; server_version only appears here.
type PullChange struct {
	Entity        string    `json:"entity"`
	ID            uuid.UUID `json:"id"`
	ServerVersion int64     `json:"server_version"`
	Data          any       `json:"data"`
}

// Entitlement is the premium status in the pull meta.
type Entitlement struct {
	Premium   bool    `json:"premium"`
	ExpiresAt *string `json:"expires_at"`
	WillRenew bool    `json:"will_renew"`
	ProductID string  `json:"product_id,omitempty"`
	Store     string  `json:"store,omitempty"`
}

// PullMeta is read-only information that travels with every pull.
type PullMeta struct {
	Entitlement Entitlement `json:"entitlement"`
	ServerTime  string      `json:"server_time"`
}

// PullResponse is the body of GET /v1/sync/pull.
type PullResponse struct {
	Changes    []PullChange `json:"changes"`
	NextCursor int64        `json:"next_cursor"`
	HasMore    bool         `json:"has_more"`
	Meta       PullMeta     `json:"meta"`
}
