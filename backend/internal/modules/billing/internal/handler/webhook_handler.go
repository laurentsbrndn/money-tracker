// Package handler serves the billing endpoints.
package handler

import (
	"encoding/json"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/billing/internal/dto"
	"moneytracker/internal/modules/billing/internal/service"
	"moneytracker/internal/platform/httpx"
)

// WebhookHandler serves POST /v1/billing/webhooks/revenuecat. The route is guarded by the
// shared secret before it reaches this handler.
type WebhookHandler struct {
	svc *service.WebhookService
}

// NewWebhookHandler builds the handler.
func NewWebhookHandler(svc *service.WebhookService) *WebhookHandler {
	return &WebhookHandler{svc: svc}
}

// Receive stores and processes one webhook. A 200 tells RevenueCat the event is settled, also
// when the outcome is permanent (unknown user, ignored event, duplicate, a state that cannot be
// derived; the reason is kept on the event). A transient failure or a storage failure is a 500,
// so RevenueCat sends the event again.
func (h *WebhookHandler) Receive(c fiber.Ctx) error {
	raw := append([]byte(nil), c.Body()...)
	var hook dto.RevenueCatWebhook
	if err := json.Unmarshal(raw, &hook); err != nil {
		return httpx.Validation("Body bukan JSON yang valid")
	}
	if err := httpx.Validate(hook); err != nil {
		return err
	}
	if err := h.svc.Handle(c.Context(), raw, hook); err != nil {
		return httpx.Internal(err)
	}
	return c.SendStatus(fiber.StatusOK)
}
