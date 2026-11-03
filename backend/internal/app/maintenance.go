package app

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"time"

	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"

	"moneytracker/internal/modules/identity"
	syncmod "moneytracker/internal/modules/sync"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/httpx"
)

// Retention periods of the maintenance job (docs/API.md §7, docs/BACKEND.md §6.1).
const (
	// idempotencyRetention is how long a stored push response is kept.
	idempotencyRetention = 24 * time.Hour
	// expiredTokenRetention is how long an expired refresh/verification token is kept.
	expiredTokenRetention = 7 * 24 * time.Hour
	// deletionGracePeriod is how long an account stays in pending_deletion before it is purged.
	deletionGracePeriod = 30 * 24 * time.Hour
	// purgeBatchSize bounds the accounts purged per run, so one run fits a serverless
	// invocation. Accounts left over are picked up by the next daily run.
	purgeBatchSize = 50
)

type cronResponse struct {
	Status string `json:"status"`
}

// maintenance is the daily cleanup job behind GET /v1/internal/cron/maintenance.
type maintenance struct {
	db       *database.TxManager
	clock    clock.Clock
	log      *slog.Logger
	identity *identity.Module
	sync     *syncmod.Module
	// purgers delete a user's data; the order is children first, the users row last.
	purgers []identity.UserPurger
}

// Handle runs every task. A failing task is logged and does not stop the others; the job
// answers 500 when any of them failed, so the failure shows up in the cron logs (Vercel does
// not retry, and every task is idempotent, so the next run starts again).
func (m *maintenance) Handle(c fiber.Ctx) error {
	ctx := c.Context()
	now := m.clock.Now()
	var errs []error

	if n, err := m.sync.DeleteExpiredKeys(ctx, now.Add(-idempotencyRetention)); err != nil {
		errs = append(errs, fmt.Errorf("delete idempotency keys: %w", err))
	} else {
		m.log.InfoContext(ctx, "maintenance: idempotency keys deleted", "count", n)
	}

	refresh, verification, err := m.identity.DeleteExpiredTokens(ctx, now.Add(-expiredTokenRetention))
	if err != nil {
		errs = append(errs, fmt.Errorf("delete expired tokens: %w", err))
	} else {
		m.log.InfoContext(ctx, "maintenance: expired tokens deleted", "refresh_tokens", refresh, "verification_tokens", verification)
	}

	purged, err := m.purgeAccounts(ctx, now.Add(-deletionGracePeriod))
	errs = append(errs, err)
	m.log.InfoContext(ctx, "maintenance: accounts purged", "count", purged)

	if err := errors.Join(errs...); err != nil {
		return httpx.Internal(err)
	}
	return httpx.OK(c, cronResponse{Status: "ok"})
}

// purgeAccounts permanently deletes the accounts whose deletion was requested before cutoff.
// Each account is purged in its own transaction across all modules, so a user is removed
// completely or not at all; one failing account does not block the others.
func (m *maintenance) purgeAccounts(ctx context.Context, cutoff time.Time) (int, error) {
	ids, err := m.identity.PendingDeletion(ctx, cutoff, purgeBatchSize)
	if err != nil {
		return 0, fmt.Errorf("list accounts pending deletion: %w", err)
	}
	var errs []error
	purged := 0
	for _, id := range ids {
		if err := m.purgeUser(ctx, id); err != nil {
			m.log.ErrorContext(ctx, "maintenance: purge user failed", "user_id", id, "error", err)
			errs = append(errs, fmt.Errorf("purge user %s: %w", id, err))
			continue
		}
		purged++
	}
	return purged, errors.Join(errs...)
}

// purgeUser runs every module's PurgeUser in one transaction, in the order of m.purgers.
func (m *maintenance) purgeUser(ctx context.Context, userID uuid.UUID) error {
	return m.db.WithTx(ctx, func(ctx context.Context) error {
		for _, p := range m.purgers {
			if err := p.PurgeUser(ctx, userID); err != nil {
				return err
			}
		}
		return nil
	})
}
