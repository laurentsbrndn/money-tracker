package httpx

import (
	"net/http"

	"github.com/gofiber/fiber/v3"
)

// OK sends v as a 200 JSON response.
func OK(c fiber.Ctx, v any) error {
	return c.Status(http.StatusOK).JSON(v)
}

// Created sends v as a 201 JSON response.
func Created(c fiber.Ctx, v any) error {
	return c.Status(http.StatusCreated).JSON(v)
}

// Accepted sends a 202 response without a body.
func Accepted(c fiber.Ctx) error {
	return c.SendStatus(http.StatusAccepted)
}

// NoContent sends a 204 response.
func NoContent(c fiber.Ctx) error {
	return c.SendStatus(http.StatusNoContent)
}
