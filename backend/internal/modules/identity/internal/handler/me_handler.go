package handler

import (
	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/modules/identity/internal/dto"
	"moneytracker/internal/modules/identity/internal/service"
	"moneytracker/internal/platform/httpx"
)

// MeHandler serves /v1/me.
type MeHandler struct {
	account *service.AccountService
}

// NewMeHandler builds the handler.
func NewMeHandler(account *service.AccountService) *MeHandler {
	return &MeHandler{account: account}
}

// Get handles GET /v1/me.
func (h *MeHandler) Get(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	user, ent, err := h.account.Me(c.Context(), userID)
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.MeResponse{User: dto.NewUser(user), Entitlement: dto.NewEntitlement(ent)})
}

// Update handles PATCH /v1/me.
func (h *MeHandler) Update(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	req, err := httpx.BindAndValidate[dto.UpdateMeRequest](c)
	if err != nil {
		return err
	}
	user, err := h.account.UpdateName(c.Context(), userID, req.Name)
	if err != nil {
		return mapError(err)
	}
	return httpx.OK(c, dto.UserEnvelope{User: dto.NewUser(user)})
}

// Delete handles DELETE /v1/me.
func (h *MeHandler) Delete(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	req, err := httpx.BindAndValidate[dto.DeleteMeRequest](c)
	if err != nil {
		return err
	}
	if err := h.account.Delete(c.Context(), userID, req.Confirmation); err != nil {
		return mapError(err)
	}
	return httpx.Accepted(c)
}
