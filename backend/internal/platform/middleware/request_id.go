package middleware

import (
	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/httpx"
	"moneytracker/internal/platform/idgen"
)

const (
	headerRequestID = "X-Request-ID"
	maxRequestIDLen = 64
)

// RequestID stores a request ID in locals and echoes it in X-Request-ID.
// A client-supplied value is reused when it is short and made of safe characters.
func RequestID() fiber.Handler {
	return func(c fiber.Ctx) error {
		id := c.Get(headerRequestID)
		if !validRequestID(id) {
			generated, err := idgen.NewV7()
			if err != nil {
				return httpx.Internal(err)
			}
			id = generated.String()
		}
		c.Locals(httpx.LocalRequestID, id)
		c.Set(headerRequestID, id)
		return c.Next()
	}
}

func validRequestID(id string) bool {
	if id == "" || len(id) > maxRequestIDLen {
		return false
	}
	for _, r := range id {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9', r == '-', r == '_':
		default:
			return false
		}
	}
	return true
}
