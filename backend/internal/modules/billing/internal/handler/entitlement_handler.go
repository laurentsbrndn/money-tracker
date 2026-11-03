package handler

import (
	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/billing/internal/service"
	"moneytracker/internal/platform/httpx"
	"moneytracker/internal/platform/syncbase"
)

// EntitlementHandler serves GET /v1/me/entitlements.
type EntitlementHandler struct {
	svc *service.EntitlementService
}

// NewEntitlementHandler builds the handler.
func NewEntitlementHandler(svc *service.EntitlementService) *EntitlementHandler {
	return &EntitlementHandler{svc: svc}
}

type entitlementResponse struct {
	Premium   bool    `json:"premium"`
	ExpiresAt *string `json:"expires_at"`
	WillRenew bool    `json:"will_renew"`
	ProductID string  `json:"product_id,omitempty"`
	Store     string  `json:"store,omitempty"`
}

// Get returns the entitlement of the signed-in user.
func (h *EntitlementHandler) Get(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	ent, err := h.svc.Get(c.Context(), userID)
	if err != nil {
		return httpx.Internal(err)
	}
	out := entitlementResponse{Premium: ent.Premium, WillRenew: ent.WillRenew, ProductID: ent.ProductID, Store: ent.Store}
	if ent.ExpiresAt != nil {
		s := syncbase.FormatTime(*ent.ExpiresAt)
		out.ExpiresAt = &s
	}
	return httpx.OK(c, out)
}
