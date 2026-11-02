package httpx

import (
	"errors"
	"log/slog"
	"net/http"

	"github.com/gofiber/fiber/v3"
)

// ErrorHandler returns the Fiber error handler that renders every error as problem+json.
// Server errors are logged with the request ID; their causes are never sent to the client.
func ErrorHandler(log *slog.Logger) fiber.ErrorHandler {
	return func(c fiber.Ctx, err error) error {
		requestID := RequestID(c)
		appErr := toAppError(err)

		if appErr.Status >= http.StatusInternalServerError {
			log.ErrorContext(c.Context(), "request failed",
				"request_id", requestID,
				"method", c.Method(),
				"path", c.Path(),
				"code", appErr.Code,
				"error", err,
			)
		}

		c.Set(fiber.HeaderCacheControl, "no-store")
		return c.Status(appErr.Status).JSON(NewProblem(appErr, requestID), ProblemContentType)
	}
}

func toAppError(err error) *AppError {
	if appErr, ok := As(err); ok {
		return appErr
	}

	var fiberErr *fiber.Error
	if errors.As(err, &fiberErr) {
		switch fiberErr.Code {
		case fiber.StatusNotFound, fiber.StatusMethodNotAllowed:
			return NotFound("Resource tidak ditemukan")
		case fiber.StatusRequestEntityTooLarge:
			return New(http.StatusRequestEntityTooLarge, CodePayloadTooLarge, "Ukuran request terlalu besar")
		case fiber.StatusTooManyRequests:
			return New(http.StatusTooManyRequests, CodeRateLimited, "Terlalu banyak request")
		case fiber.StatusBadRequest, fiber.StatusUnprocessableEntity:
			return Validation("Request tidak valid")
		}
	}
	return Internal(err)
}
