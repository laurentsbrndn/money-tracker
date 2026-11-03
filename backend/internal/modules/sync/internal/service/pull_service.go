package service

import (
	"context"
	"sort"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/sync/internal/dto"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// Pull page sizes (docs/SYNC_PROTOCOL.md §9.1).
const (
	DefaultPullLimit = 500
	MaxPullLimit     = 1000
)

// PullService returns the changes of a user after a cursor (docs/SYNC_PROTOCOL.md §9).
type PullService struct {
	db       *database.TxManager
	registry *Registry
	billing  billing.Entitlements
	clock    clock.Clock
}

// NewPullService builds the service.
func NewPullService(db *database.TxManager, registry *Registry, bill billing.Entitlements, clk clock.Clock) *PullService {
	return &PullService{db: db, registry: registry, billing: bill, clock: clk}
}

// Pull merges the rows of every entity with server_version > since, ordered by server_version
// and cut to limit.
//
// All tables are read in one REPEATABLE READ snapshot. Without it, a push that commits
// between two table reads could make the cursor jump past a row the first read missed:
// writers of one user commit in server_version order (they hold the user lock), and a single
// snapshot shows a prefix of that order in every table.
func (s *PullService) Pull(ctx context.Context, userID uuid.UUID, since int64, limit int) (dto.PullResponse, error) {
	var rows []syncbase.PulledRow
	err := s.db.WithReadSnapshot(ctx, func(ctx context.Context) error {
		for _, handler := range s.registry.All() {
			// limit+1 rows from each entity are enough to know whether more exist.
			part, err := handler.PullSince(ctx, userID, since, limit+1)
			if err != nil {
				return err
			}
			rows = append(rows, part...)
		}
		return nil
	})
	if err != nil {
		return dto.PullResponse{}, err
	}

	sort.Slice(rows, func(i, j int) bool { return rows[i].ServerVersion < rows[j].ServerVersion })
	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}

	next := since
	changes := make([]dto.PullChange, 0, len(rows))
	for _, row := range rows {
		changes = append(changes, dto.PullChange{
			Entity: row.Entity, ID: row.ID, ServerVersion: row.ServerVersion, Data: row.Data,
		})
		next = row.ServerVersion
	}

	ent, err := s.billing.Get(ctx, userID)
	if err != nil {
		return dto.PullResponse{}, err
	}
	meta := dto.PullMeta{
		Entitlement: dto.Entitlement{
			Premium: ent.Premium, WillRenew: ent.WillRenew, ProductID: ent.ProductID, Store: ent.Store,
		},
		ServerTime: syncbase.FormatTime(s.clock.Now()),
	}
	if ent.ExpiresAt != nil {
		expires := syncbase.FormatTime(*ent.ExpiresAt)
		meta.Entitlement.ExpiresAt = &expires
	}
	return dto.PullResponse{Changes: changes, NextCursor: next, HasMore: hasMore, Meta: meta}, nil
}
