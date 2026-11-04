package middleware

import "github.com/gofiber/fiber/v3"

// SecurityHeaders sets conservative response headers for a JSON API consumed by native apps:
// no MIME sniffing, no framing, no referrer, and no caching of authenticated responses.
// Headers are set before the chain runs so error responses carry them too.
func SecurityHeaders() fiber.Handler {
	return func(c fiber.Ctx) error {
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("X-Frame-Options", "DENY")
		c.Set("Referrer-Policy", "no-referrer")
		c.Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")
		c.Set(fiber.HeaderCacheControl, "no-store")
		return c.Next()
	}
}
