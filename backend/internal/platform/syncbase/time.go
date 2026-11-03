package syncbase

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// wireTimeLayout is the only timestamp format on the sync wire: UTC, exactly three fractional
// digits, suffix Z (docs/SYNC_PROTOCOL.md §4).
const wireTimeLayout = "2006-01-02T15:04:05.000Z"

// Time is a timestamp with millisecond precision. It is truncated (never rounded) to the
// millisecond when decoded, stored, and encoded, so the value a client pushed comes back
// byte-for-byte equal in pulls and responses.
type Time time.Time

// NewTime converts t to UTC and truncates it to the millisecond.
func NewTime(t time.Time) Time {
	return Time(t.UTC().Truncate(time.Millisecond))
}

// Std returns the value as a time.Time.
func (t Time) Std() time.Time {
	return time.Time(t)
}

// IsZero reports whether t is the zero time.
func (t Time) IsZero() bool {
	return time.Time(t).IsZero()
}

// FormatTime formats t in the wire format (UTC, milliseconds, truncated).
func FormatTime(t time.Time) string {
	return t.UTC().Truncate(time.Millisecond).Format(wireTimeLayout)
}

// MarshalJSON encodes t in the wire format.
func (t Time) MarshalJSON() ([]byte, error) {
	return json.Marshal(FormatTime(time.Time(t)))
}

// UnmarshalJSON decodes an RFC 3339 timestamp with any fractional precision and zone.
func (t *Time) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return fmt.Errorf("decode timestamp: %w", err)
	}
	parsed, err := time.Parse(time.RFC3339Nano, s)
	if err != nil {
		return fmt.Errorf("decode timestamp %q: %w", s, err)
	}
	*t = NewTime(parsed)
	return nil
}

// Value implements driver.Valuer.
func (t Time) Value() (driver.Value, error) {
	return time.Time(t).UTC().Truncate(time.Millisecond), nil
}

// Scan implements sql.Scanner.
func (t *Time) Scan(src any) error {
	switch v := src.(type) {
	case nil:
		*t = Time{}
	case time.Time:
		*t = NewTime(v)
	default:
		return fmt.Errorf("scan timestamp: unsupported type %T", src)
	}
	return nil
}
