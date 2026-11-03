package syncbase

import (
	"context"

	"github.com/google/uuid"
)

// EntityHandler is the Handler shared by all entities: lookup, tombstone paging and the
// envelope come from Repository; validation and writes come from the entity's service.
type EntityHandler[T any, P interface {
	*T
	Row
}] struct {
	entity string
	repo   *Repository[T, P]
	upsert func(ctx context.Context, userID uuid.UUID, c Change) error
	delete func(ctx context.Context, userID uuid.UUID, c Change) error
}

// NewEntityHandler builds the Handler for one entity. upsert and delete return a
// *RejectError to reject the change.
func NewEntityHandler[T any, P interface {
	*T
	Row
}](
	entity string,
	repo *Repository[T, P],
	upsert func(ctx context.Context, userID uuid.UUID, c Change) error,
	del func(ctx context.Context, userID uuid.UUID, c Change) error,
) *EntityHandler[T, P] {
	return &EntityHandler[T, P]{entity: entity, repo: repo, upsert: upsert, delete: del}
}

// Entity returns the wire name of the entity.
func (h *EntityHandler[T, P]) Entity() string {
	return h.entity
}

// LoadForWrite fetches the row without a user filter.
func (h *EntityHandler[T, P]) LoadForWrite(ctx context.Context, id uuid.UUID) (*Existing, error) {
	row, err := h.repo.FindAnyUser(ctx, id)
	if err != nil || row == nil {
		return nil, err
	}
	c := row.Sync()
	return &Existing{UserID: c.UserID, UpdatedAt: c.UpdatedAt.Std(), ServerVersion: c.ServerVersion}, nil
}

// Upsert validates and writes the whole row.
func (h *EntityHandler[T, P]) Upsert(ctx context.Context, userID uuid.UUID, c Change) error {
	return h.upsert(ctx, userID, c)
}

// Delete writes the tombstone.
func (h *EntityHandler[T, P]) Delete(ctx context.Context, userID uuid.UUID, c Change) error {
	return h.delete(ctx, userID, c)
}

// PullSince returns the user's rows changed after the cursor.
func (h *EntityHandler[T, P]) PullSince(ctx context.Context, userID uuid.UUID, since int64, limit int) ([]PulledRow, error) {
	rows, err := h.repo.PullSince(ctx, userID, since, limit)
	if err != nil {
		return nil, err
	}
	out := make([]PulledRow, 0, len(rows))
	for i := range rows {
		c := P(&rows[i]).Sync()
		out = append(out, PulledRow{Entity: h.entity, ID: c.ID, ServerVersion: c.ServerVersion, Data: rows[i]})
	}
	return out, nil
}
