// Package handler serves the ledger endpoints that are not part of sync.
package handler

import (
	"log/slog"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/platform/httpx"
)

// CronRecurringHandler serves GET /v1/internal/cron/recurring (guarded by CronAuth).
type CronRecurringHandler struct {
	gen *service.RecurringGenerator
	log *slog.Logger
}

// NewCronRecurringHandler builds the handler.
func NewCronRecurringHandler(gen *service.RecurringGenerator, log *slog.Logger) *CronRecurringHandler {
	return &CronRecurringHandler{gen: gen, log: log}
}

// cronResponse is the CronResult of the contract (`status`) plus the batch outcome.
type cronResponse struct {
	Status    string `json:"status"`
	Processed int    `json:"processed"`
	HasMore   bool   `json:"has_more"`
}

// Run creates the due occurrences of every user. The job answers 500 when any user failed, so
// the failure shows in the cron logs (Vercel does not retry; the next run starts again and is
// idempotent because occurrence ids are deterministic).
func (h *CronRecurringHandler) Run(c fiber.Ctx) error {
	res, err := h.gen.Run(c.Context())
	h.log.InfoContext(c.Context(), "recurring: run finished",
		"users", res.Users, "created", res.Created, "paused", res.Paused, "failed", res.Failed, "has_more", res.HasMore)
	if err != nil {
		return httpx.Internal(err)
	}
	return httpx.OK(c, cronResponse{Status: "ok", Processed: res.Users, HasMore: res.HasMore})
}
