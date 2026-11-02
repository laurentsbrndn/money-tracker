package syncbase

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/platform/httpx"
)

// Op is the operation of a pushed change.
type Op string

const (
	OpUpsert Op = "upsert"
	OpDelete Op = "delete"
)

// Change is one entry of a push request. Data holds the whole row for upsert and is empty for delete.
type Change struct {
	Entity    string
	Op        Op
	ID        uuid.UUID
	UpdatedAt time.Time
	Data      json.RawMessage
}

// ResultStatus is the outcome of one pushed change.
type ResultStatus string

const (
	StatusApplied  ResultStatus = "applied"
	StatusStale    ResultStatus = "stale"
	StatusRejected ResultStatus = "rejected"
)

// RejectCode explains why a change was rejected (docs/SYNC_PROTOCOL.md §8.3).
type RejectCode string

const (
	RejectValidation       RejectCode = "validation"
	RejectReferenceMissing RejectCode = "reference_missing"
	RejectForbidden        RejectCode = "forbidden"
	RejectPlanLimit        RejectCode = "plan_limit"
	RejectUnknownEntity    RejectCode = "unknown_entity"
)

// RejectError is returned by a Handler to reject a change. The sync service rolls back the
// entry's savepoint and reports it as rejected.
type RejectError struct {
	Code      RejectCode
	Message   string
	Retryable bool
	Fields    []httpx.FieldError
}

// Error implements error.
func (e *RejectError) Error() string {
	return string(e.Code) + ": " + e.Message
}

// Result is the per-change response of a push.
type Result struct {
	Entity        string
	ID            uuid.UUID
	Status        ResultStatus
	ServerVersion *int64 // nil for a delete no-op and for rejected changes
	Error         *RejectError
}

// PulledRow is one row returned by Handler.PullSince.
type PulledRow struct {
	Entity        string
	ID            uuid.UUID
	ServerVersion int64
	Data          any // the entity row, serialized by its json tags
}
