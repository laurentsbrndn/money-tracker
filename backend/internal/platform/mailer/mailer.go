package mailer

import "context"

// Message is a transactional email.
type Message struct {
	To      string
	Subject string
	Text    string
	HTML    string
}

// Mailer sends transactional email (verification and reset codes).
type Mailer interface {
	Send(ctx context.Context, msg Message) error
}
