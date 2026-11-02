package httpx

import "net/http"

const (
	// ProblemContentType is the RFC 9457 media type.
	ProblemContentType = "application/problem+json"

	problemTypeBase = "https://moneytracker.app/errors/"
)

// Problem is the RFC 9457 body (docs/API.md §1.2).
type Problem struct {
	Type              string       `json:"type"`
	Title             string       `json:"title"`
	Status            int          `json:"status"`
	Detail            string       `json:"detail,omitempty"`
	Code              string       `json:"code"`
	Fields            []FieldError `json:"fields,omitempty"`
	RetryAfterSeconds int          `json:"retry_after_seconds,omitempty"`
	RequestID         string       `json:"request_id,omitempty"`
}

// NewProblem converts an AppError to its wire form.
func NewProblem(e *AppError, requestID string) Problem {
	return Problem{
		Type:              problemTypeBase + e.Code,
		Title:             http.StatusText(e.Status),
		Status:            e.Status,
		Detail:            e.Detail,
		Code:              e.Code,
		Fields:            e.Fields,
		RetryAfterSeconds: e.RetryAfterSeconds,
		RequestID:         requestID,
	}
}
