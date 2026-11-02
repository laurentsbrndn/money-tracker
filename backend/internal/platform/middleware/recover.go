package middleware

import (
	"fmt"
	"log/slog"
	"runtime/debug"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/httpx"
)

// Recover turns a panic in a downstream handler into a 500 internal error.
// The panic value and stack are logged with the request ID, never sent to the client.
func Recover(log *slog.Logger) fiber.Handler {
	return func(c fiber.Ctx) (err error) {
		defer func() {
			if r := recover(); r != nil {
				log.ErrorContext(c.Context(), "panic recovered",
					"request_id", httpx.RequestID(c),
					"method", c.Method(),
					"path", c.Path(),
					"panic", fmt.Sprint(r),
					"stack", string(debug.Stack()),
				)
				err = httpx.Internal(fmt.Errorf("panic: %v", r))
			}
		}()
		return c.Next()
	}
}
