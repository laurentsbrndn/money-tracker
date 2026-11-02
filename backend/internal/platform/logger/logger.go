package logger

import (
	"log/slog"
	"os"
	"strings"
)

// New builds a JSON logger that writes to stdout (visible in Vercel Logs).
// Unknown levels fall back to info.
func New(level string) *slog.Logger {
	return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: ParseLevel(level)}))
}

// ParseLevel converts a LOG_LEVEL value to a slog level.
func ParseLevel(level string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(level)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
