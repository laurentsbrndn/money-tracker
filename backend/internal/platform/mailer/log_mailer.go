package mailer

import (
	"context"
	"log/slog"
)

// LogMailer writes emails to the log instead of sending them. Local development only:
// the log contains the message body, including verification codes.
type LogMailer struct {
	log *slog.Logger
}

// NewLogMailer builds a mailer that logs messages.
func NewLogMailer(log *slog.Logger) *LogMailer {
	return &LogMailer{log: log}
}

// Send logs msg.
func (m *LogMailer) Send(ctx context.Context, msg Message) error {
	m.log.InfoContext(ctx, "email (not sent, log mailer)", "to", msg.To, "subject", msg.Subject, "text", msg.Text)
	return nil
}
