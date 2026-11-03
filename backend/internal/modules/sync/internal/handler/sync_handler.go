// Package handler holds the Fiber handlers of the sync module.
package handler

import (
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/sync/internal/dto"
	"moneytracker/internal/modules/sync/internal/service"
	"moneytracker/internal/platform/httpx"
)

const (
	headerIdempotencyKey = "Idempotency-Key"
	maxIdempotencyKeyLen = 64
)

// SyncHandler serves /v1/sync/*.
type SyncHandler struct {
	push *service.PushService
	pull *service.PullService
}

// NewSyncHandler builds the handler.
func NewSyncHandler(push *service.PushService, pull *service.PullService) *SyncHandler {
	return &SyncHandler{push: push, pull: pull}
}

// Push handles POST /v1/sync/push.
func (h *SyncHandler) Push(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	key := strings.TrimSpace(c.Get(headerIdempotencyKey))
	if key == "" || len(key) > maxIdempotencyKeyLen {
		return httpx.Validation("Header Idempotency-Key tidak valid",
			httpx.FieldError{Field: headerIdempotencyKey, Message: "wajib diisi, maksimal 64 karakter"})
	}
	req, err := httpx.BindAndValidate[dto.PushRequest](c)
	if err != nil {
		return err
	}
	response, err := h.push.Push(c.Context(), userID, key, req)
	if err != nil {
		return httpx.Internal(err)
	}
	return httpx.OK(c, response)
}

// Pull handles GET /v1/sync/pull?since=&limit=.
func (h *SyncHandler) Pull(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	since, err := strconv.ParseInt(c.Query("since"), 10, 64)
	if err != nil || since < 0 {
		return httpx.Validation("Parameter tidak valid",
			httpx.FieldError{Field: "since", Message: "wajib berupa bilangan bulat >= 0"})
	}
	limit := service.DefaultPullLimit
	if raw := c.Query("limit"); raw != "" {
		limit, err = strconv.Atoi(raw)
		if err != nil || limit < 1 || limit > service.MaxPullLimit {
			return httpx.Validation("Parameter tidak valid",
				httpx.FieldError{Field: "limit", Message: "harus 1 sampai 1000"})
		}
	}
	response, err := h.pull.Pull(c.Context(), userID, since, limit)
	if err != nil {
		return httpx.Internal(err)
	}
	return httpx.OK(c, response)
}
