package middleware

import (
	"log/slog"
	"time"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/httpx"
)

// AccessLog logs one structured line per request. It never logs headers, query strings,
// or bodies (tokens, passwords, and transactions must stay out of the logs).
//
// Errors from downstream handlers are rendered here (through the app's ErrorHandler) so the
// logged status is the one actually sent.
func AccessLog(log *slog.Logger) fiber.Handler {
	return func(c fiber.Ctx) error {
		start := time.Now()
		chainErr := c.Next()
		if chainErr != nil {
			if err := c.App().Config().ErrorHandler(c, chainErr); err != nil {
				_ = c.SendStatus(fiber.StatusInternalServerError)
			}
		}

		attrs := []any{
			"request_id", httpx.RequestID(c),
			"method", c.Method(),
			"path", c.Path(),
			"status", c.Response().StatusCode(),
			"duration_ms", time.Since(start).Milliseconds(),
			"ip", c.IP(),
		}
		if userID, ok := httpx.UserID(c); ok {
			attrs = append(attrs, "user_id", userID.String())
		}
		log.InfoContext(c.Context(), "request", attrs...)
		return nil
	}
}
