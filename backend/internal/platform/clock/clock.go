package clock

import "time"

// Clock supplies the current time so that time-dependent code can be driven by a fake clock.
type Clock interface {
	Now() time.Time
}

// System is the real clock. It always returns UTC.
type System struct{}

// NewSystem returns the real clock.
func NewSystem() System {
	return System{}
}

// Now returns the current time in UTC.
func (System) Now() time.Time {
	return time.Now().UTC()
}
