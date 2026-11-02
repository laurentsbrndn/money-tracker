package mailer

import (
	"context"
	"fmt"

	"github.com/resend/resend-go/v2"
)

// ResendMailer sends email through Resend.
type ResendMailer struct {
	client *resend.Client
	from   string
}

// NewResendMailer builds a mailer for the given API key and sender ("Name <addr>").
func NewResendMailer(apiKey, from string) *ResendMailer {
	return &ResendMailer{client: resend.NewClient(apiKey), from: from}
}

// Send delivers msg.
func (m *ResendMailer) Send(ctx context.Context, msg Message) error {
	_, err := m.client.Emails.SendWithContext(ctx, &resend.SendEmailRequest{
		From:    m.from,
		To:      []string{msg.To},
		Subject: msg.Subject,
		Text:    msg.Text,
		Html:    msg.HTML,
	})
	if err != nil {
		return fmt.Errorf("send email via resend: %w", err)
	}
	return nil
}
