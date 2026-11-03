// Package dto holds the HTTP shapes of the sync module (contracts/openapi.yaml).
package dto

import (
	"encoding/json"

	"github.com/google/uuid"

	"moneytracker/internal/platform/httpx"
	"moneytracker/internal/platform/syncbase"
)

// PushRequest is the body of POST /v1/sync/push. At most 100 changes.
type PushRequest struct {
	Changes []PushChange `json:"changes" validate:"required,min=1,max=100,dive"`
}

// PushChange is one entry of the outbox. An unknown entity is not a request error: it is
// rejected for that entry only.
type PushChange struct {
	Entity    string          `json:"entity" validate:"required"`
	Op        string          `json:"op" validate:"required,oneof=upsert delete"`
	ID        uuid.UUID       `json:"id" validate:"required"`
	UpdatedAt *syncbase.Time  `json:"updated_at" validate:"required"`
	Data      json.RawMessage `json:"data"`
}

// PushError explains a rejected entry.
type PushError struct {
	Code      string             `json:"code"`
	Message   string             `json:"message"`
	Retryable bool               `json:"retryable"`
	Fields    []httpx.FieldError `json:"fields,omitempty"`
}

// PushResult is the outcome of one entry. ServerVersion is null for a delete no-op and for
// rejected entries.
type PushResult struct {
	Entity        string     `json:"entity"`
	ID            uuid.UUID  `json:"id"`
	Status        string     `json:"status"`
	ServerVersion *int64     `json:"server_version"`
	Error         *PushError `json:"error,omitempty"`
}

// PushResponse is the body of a push answer.
type PushResponse struct {
	Results    []PushResult `json:"results"`
	ServerTime string       `json:"server_time"`
}
