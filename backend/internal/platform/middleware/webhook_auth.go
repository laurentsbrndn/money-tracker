package middleware

import "github.com/gofiber/fiber/v3"

// WebhookAuth guards the RevenueCat webhook with "Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>".
func WebhookAuth(secret string) fiber.Handler {
	return requireBearerSecret(secret)
}
