package middleware

import "github.com/gofiber/fiber/v3"

// CronAuth guards /v1/internal/cron/* with "Authorization: Bearer <CRON_SECRET>",
// the header Vercel Cron sends.
func CronAuth(secret string) fiber.Handler {
	return requireBearerSecret(secret)
}
