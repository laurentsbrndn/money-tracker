package syncbase

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// Existing is the minimum a Handler reports about a stored row for ownership and LWW checks.
type Existing struct {
	UserID    uuid.UUID
	UpdatedAt time.Time
}

// Handler implements sync for one entity. Each owning module registers one per entity.
type Handler interface {
	// Entity returns the entity name used on the wire (docs/SYNC_PROTOCOL.md §2).
	Entity() string
	// LoadForWrite fetches the row by id without a user filter (ownership and LWW checks).
	// It returns (nil, nil) when the row does not exist.
	LoadForWrite(ctx context.Context, id uuid.UUID) (*Existing, error)
	// Upsert validates and writes the whole row. A *RejectError rejects the change.
	Upsert(ctx context.Context, userID uuid.UUID, c Change) error
	// Delete writes the tombstone.
	Delete(ctx context.Context, userID uuid.UUID, c Change) error
	// PullSince returns the user's rows with server_version > since, ordered ascending.
	PullSince(ctx context.Context, userID uuid.UUID, since int64, limit int) ([]PulledRow, error)
}
