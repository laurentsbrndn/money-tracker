package httpx

import (
	"errors"
	"fmt"
	"net/http"
)

// Error codes (docs/API.md §1.2). Codes are stable; apps branch on them.
const (
	CodeValidation         = "validation"
	CodeUnauthorized       = "unauthorized"
	CodeTokenExpired       = "token_expired"
	CodeRefreshInvalid     = "refresh_invalid"
	CodeRefreshReused      = "refresh_reused"
	CodeInvalidCredentials = "invalid_credentials"
	CodeAccountLocked      = "account_locked"
	CodeEmailTaken         = "email_taken"
	CodeCodeInvalid        = "code_invalid"
	CodeCodeExpired        = "code_expired"
	CodeTooManyAttempts    = "too_many_attempts"
	CodeForbidden          = "forbidden"
	CodeNotFound           = "not_found"
	CodePremiumRequired    = "premium_required"
	CodeHistoryLimit       = "history_limit"
	CodePayloadTooLarge    = "payload_too_large"
	CodeRateLimited        = "rate_limited"
	CodeUpgradeRequired    = "upgrade_required"
	CodeInternal           = "internal"
)

// FieldError describes one invalid field in a validation error.
type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// AppError is the only error type the HTTP layer renders to clients.
type AppError struct {
	Status            int
	Code              string
	Detail            string
	Fields            []FieldError
	RetryAfterSeconds int
	// Err is the underlying cause. It is logged but never sent to the client.
	Err error
}

// Error implements error.
func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s (%d): %s: %v", e.Code, e.Status, e.Detail, e.Err)
	}
	return fmt.Sprintf("%s (%d): %s", e.Code, e.Status, e.Detail)
}

// Unwrap exposes the underlying cause.
func (e *AppError) Unwrap() error {
	return e.Err
}

// As extracts an *AppError from err's chain.
func As(err error) (*AppError, bool) {
	var appErr *AppError
	if errors.As(err, &appErr) {
		return appErr, true
	}
	return nil, false
}

// New builds an AppError.
func New(status int, code, detail string) *AppError {
	return &AppError{Status: status, Code: code, Detail: detail}
}

// Validation builds a 422 validation error with per-field messages.
func Validation(detail string, fields ...FieldError) *AppError {
	return &AppError{Status: http.StatusUnprocessableEntity, Code: CodeValidation, Detail: detail, Fields: fields}
}

// Unauthorized builds a 401 unauthorized error.
func Unauthorized(detail string) *AppError {
	return New(http.StatusUnauthorized, CodeUnauthorized, detail)
}

// Forbidden builds a 403 forbidden error.
func Forbidden(detail string) *AppError {
	return New(http.StatusForbidden, CodeForbidden, detail)
}

// NotFound builds a 404 not_found error.
func NotFound(detail string) *AppError {
	return New(http.StatusNotFound, CodeNotFound, detail)
}

// Internal wraps an unexpected error as a 500. The cause is logged, not exposed.
func Internal(cause error) *AppError {
	return &AppError{Status: http.StatusInternalServerError, Code: CodeInternal, Detail: "Terjadi kesalahan pada server", Err: cause}
}
