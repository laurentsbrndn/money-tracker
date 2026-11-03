package service

import (
	"errors"
	"fmt"
	"time"
)

// Domain errors. The handler layer maps them to AppError codes (docs/API.md §1.2).
var (
	ErrEmailTaken         = errors.New("email already registered")
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrCodeInvalid        = errors.New("verification code invalid")
	ErrCodeExpired        = errors.New("verification code expired")
	ErrTooManyAttempts    = errors.New("too many wrong code attempts")
	ErrRateLimited        = errors.New("rate limited")
	ErrUserNotFound       = errors.New("user not found")
	ErrRefreshInvalid     = errors.New("refresh token invalid")
	ErrRefreshReused      = errors.New("refresh token reused")
	ErrIDTokenInvalid     = errors.New("id token invalid")
	ErrOAuthUnavailable   = errors.New("oauth not configured")
	ErrAccountInactive    = errors.New("account not usable")
)

// LockedError means the account is locked after too many failed logins.
type LockedError struct {
	RetryAfter time.Duration
}

// Error implements error.
func (e *LockedError) Error() string {
	return fmt.Sprintf("account locked for %s", e.RetryAfter)
}

// FieldError describes one invalid input field.
type FieldError struct {
	Field   string
	Message string
}

// ValidationError is a business-rule validation failure.
type ValidationError struct {
	Message string
	Fields  []FieldError
}

// Error implements error.
func (e *ValidationError) Error() string {
	return "validation: " + e.Message
}

func validationOn(field, message string) *ValidationError {
	return &ValidationError{Message: message, Fields: []FieldError{{Field: field, Message: message}}}
}
