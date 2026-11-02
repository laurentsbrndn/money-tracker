package httpx

import (
	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
)

// Keys under which middleware stores request-scoped values in fiber locals.
const (
	LocalRequestID  = "request_id"
	LocalUserID     = "user_id"
	LocalSessionID  = "session_id"
	LocalClientInfo = "client_info"
)

// ClientInfo is the app identity sent in the X-Device-ID, X-Platform, X-App-Version
// and X-Device-Name headers.
type ClientInfo struct {
	DeviceID   string
	Platform   string
	AppVersion string
	DeviceName string
}

// RequestID returns the request ID set by the request_id middleware.
func RequestID(c fiber.Ctx) string {
	id, _ := c.Locals(LocalRequestID).(string)
	return id
}

// UserID returns the authenticated user ID set by the auth middleware.
func UserID(c fiber.Ctx) (uuid.UUID, bool) {
	id, ok := c.Locals(LocalUserID).(uuid.UUID)
	return id, ok
}

// SessionID returns the refresh-token family ID (access token claim sid).
func SessionID(c fiber.Ctx) (uuid.UUID, bool) {
	id, ok := c.Locals(LocalSessionID).(uuid.UUID)
	return id, ok
}

// Client returns the app identity set by the client_info middleware.
func Client(c fiber.Ctx) (ClientInfo, bool) {
	info, ok := c.Locals(LocalClientInfo).(ClientInfo)
	return info, ok
}
