package repository

import "errors"

var (
	// ErrNotFound is returned when a single-row lookup finds nothing.
	ErrNotFound = errors.New("not found")
	// ErrDuplicate is returned when an insert violates a unique index.
	ErrDuplicate = errors.New("duplicate")
)
