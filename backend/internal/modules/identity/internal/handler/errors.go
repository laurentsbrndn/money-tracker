// Package handler holds the Fiber handlers of the identity module.
package handler

import (
	"errors"
	"math"
	"net/http"

	"moneytracker/internal/modules/identity/internal/service"
	"moneytracker/internal/platform/httpx"
)

// mapError converts a service error to the AppError the client sees (docs/API.md §1.2).
// Unknown errors become 500 internal; the cause is logged by the error handler.
func mapError(err error) error {
	if err == nil {
		return nil
	}
	if _, ok := httpx.As(err); ok {
		return err
	}

	var locked *service.LockedError
	var validation *service.ValidationError
	switch {
	case errors.As(err, &locked):
		appErr := httpx.New(http.StatusLocked, httpx.CodeAccountLocked, "Terlalu banyak percobaan login, coba lagi nanti")
		appErr.RetryAfterSeconds = int(math.Ceil(locked.RetryAfter.Seconds()))
		return appErr
	case errors.As(err, &validation):
		fields := make([]httpx.FieldError, 0, len(validation.Fields))
		for _, f := range validation.Fields {
			fields = append(fields, httpx.FieldError{Field: f.Field, Message: f.Message})
		}
		return httpx.Validation(validation.Message, fields...)
	case errors.Is(err, service.ErrEmailTaken):
		return httpx.New(http.StatusConflict, httpx.CodeEmailTaken, "Email sudah terdaftar")
	case errors.Is(err, service.ErrInvalidCredentials):
		return httpx.New(http.StatusUnauthorized, httpx.CodeInvalidCredentials, "Email atau password salah")
	case errors.Is(err, service.ErrCodeInvalid):
		return httpx.New(http.StatusUnprocessableEntity, httpx.CodeCodeInvalid, "Kode salah")
	case errors.Is(err, service.ErrCodeExpired):
		return httpx.New(http.StatusUnprocessableEntity, httpx.CodeCodeExpired, "Kode sudah kedaluwarsa, minta kode baru")
	case errors.Is(err, service.ErrTooManyAttempts):
		return httpx.New(http.StatusTooManyRequests, httpx.CodeTooManyAttempts, "Terlalu banyak kode salah, minta kode baru")
	case errors.Is(err, service.ErrRateLimited):
		return httpx.New(http.StatusTooManyRequests, httpx.CodeRateLimited, "Terlalu sering meminta kode, coba lagi sebentar lagi")
	case errors.Is(err, service.ErrRefreshReused):
		return httpx.New(http.StatusUnauthorized, httpx.CodeRefreshReused, "Sesi tidak valid, silakan login ulang")
	case errors.Is(err, service.ErrRefreshInvalid):
		return httpx.New(http.StatusUnauthorized, httpx.CodeRefreshInvalid, "Sesi berakhir, silakan login ulang")
	case errors.Is(err, service.ErrIDTokenInvalid):
		return httpx.Unauthorized("ID token tidak valid")
	case errors.Is(err, service.ErrAccountInactive):
		return httpx.Unauthorized("Akun tidak dapat digunakan")
	case errors.Is(err, service.ErrOAuthUnavailable):
		return httpx.New(http.StatusInternalServerError, httpx.CodeInternal, "OAuth belum dikonfigurasi")
	case errors.Is(err, service.ErrUserNotFound):
		return httpx.Unauthorized("Akun tidak ditemukan")
	}
	return httpx.Internal(err)
}
