package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"

	"moneytracker/internal/modules/sync/internal/dto"
	"moneytracker/internal/modules/sync/internal/model"
	"moneytracker/internal/modules/sync/internal/repository"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// maxClockSkew is how far into the future a client's updated_at may be before it is replaced
// by the server time (docs/SYNC_PROTOCOL.md §8.2).
const maxClockSkew = 5 * time.Minute

// PushService applies a batch of client changes (docs/SYNC_PROTOCOL.md §8).
type PushService struct {
	db       *database.TxManager
	registry *Registry
	keys     *repository.IdempotencyKeyRepository
	clock    clock.Clock
}

// NewPushService builds the service.
func NewPushService(db *database.TxManager, registry *Registry, keys *repository.IdempotencyKeyRepository, clk clock.Clock) *PushService {
	return &PushService{db: db, registry: registry, keys: keys, clock: clk}
}

// Push applies the changes and returns one result per entry, in request order.
//
// The whole batch runs in one transaction that first takes the user's advisory lock
// (docs/SYNC_PROTOCOL.md §10), so two pushes of the same user never interleave and server
// versions of a user commit in order. Each entry runs in its own savepoint: a rejected entry
// is rolled back alone. The response is stored under the Idempotency-Key in the same
// transaction; a repeated key returns the stored response without applying anything.
func (s *PushService) Push(ctx context.Context, userID uuid.UUID, key string, req dto.PushRequest) (dto.PushResponse, error) {
	if stored, err := s.stored(ctx, userID, key); err != nil || stored != nil {
		if stored != nil {
			return *stored, nil
		}
		return dto.PushResponse{}, err
	}

	var response dto.PushResponse
	err := s.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, s.db.DB(ctx), userID); err != nil {
			return err
		}
		// A concurrent request with the same key may have finished while we waited for the lock.
		if stored, err := s.stored(ctx, userID, key); err != nil || stored != nil {
			if stored != nil {
				response = *stored
			}
			return err
		}

		now := s.clock.Now()
		results := make([]dto.PushResult, 0, len(req.Changes))
		for i, change := range req.Changes {
			result, err := s.apply(ctx, userID, change, now, i)
			if err != nil {
				return err
			}
			results = append(results, result)
		}
		response = dto.PushResponse{Results: results, ServerTime: syncbase.FormatTime(now)}

		raw, err := json.Marshal(response)
		if err != nil {
			return fmt.Errorf("encode push response: %w", err)
		}
		return s.keys.Create(ctx, &model.IdempotencyKey{
			UserID: userID, IdempotencyKey: key, Response: raw, CreatedAt: now,
		})
	})
	if err != nil {
		return dto.PushResponse{}, err
	}
	return response, nil
}

// stored returns the response saved under the key, or nil.
func (s *PushService) stored(ctx context.Context, userID uuid.UUID, key string) (*dto.PushResponse, error) {
	row, err := s.keys.Find(ctx, userID, key)
	if err != nil || row == nil {
		return nil, err
	}
	var response dto.PushResponse
	if err := json.Unmarshal(row.Response, &response); err != nil {
		return nil, fmt.Errorf("decode stored push response: %w", err)
	}
	return &response, nil
}

// apply processes one entry. Rejections are results; any other error aborts the whole batch.
func (s *PushService) apply(ctx context.Context, userID uuid.UUID, in dto.PushChange, now time.Time, index int) (dto.PushResult, error) {
	result := dto.PushResult{Entity: in.Entity, ID: in.ID}

	handler, ok := s.registry.Get(in.Entity)
	if !ok {
		return rejected(result, &syncbase.RejectError{Code: syncbase.RejectUnknownEntity, Message: "entitas tidak dikenal"}), nil
	}

	// Clamp: a client clock more than 5 minutes ahead is replaced by the server time.
	updatedAt := in.UpdatedAt.Std()
	if updatedAt.After(now.Add(maxClockSkew)) {
		updatedAt = now
	}
	change := syncbase.Change{
		Entity:    in.Entity,
		Op:        syncbase.Op(in.Op),
		ID:        in.ID,
		UpdatedAt: syncbase.NewTime(updatedAt).Std(),
		Data:      in.Data,
	}

	// Ownership and LWW look at the row by id alone, without a user filter.
	existing, err := handler.LoadForWrite(ctx, in.ID)
	if err != nil {
		return result, err
	}
	if existing != nil && existing.UserID != userID {
		return rejected(result, syncbase.Forbidden("baris milik user lain")), nil
	}
	if existing != nil && !change.UpdatedAt.After(existing.UpdatedAt) {
		version := existing.ServerVersion
		result.Status = string(syncbase.StatusStale)
		result.ServerVersion = &version
		return result, nil
	}
	if change.Op == syncbase.OpDelete && existing == nil {
		result.Status = string(syncbase.StatusApplied) // nothing to delete; no version
		return result, nil
	}

	db := s.db.DB(ctx)
	savepoint := fmt.Sprintf("sync_entry_%d", index)
	if err := db.SavePoint(savepoint).Error; err != nil {
		return result, fmt.Errorf("create savepoint: %w", err)
	}
	if change.Op == syncbase.OpDelete {
		err = handler.Delete(ctx, userID, change)
	} else {
		err = handler.Upsert(ctx, userID, change)
	}
	if err != nil {
		var reject *syncbase.RejectError
		if !errors.As(err, &reject) {
			return result, err
		}
		if err := db.RollbackTo(savepoint).Error; err != nil {
			return result, fmt.Errorf("rollback to savepoint: %w", err)
		}
		return rejected(result, reject), nil
	}

	written, err := handler.LoadForWrite(ctx, in.ID)
	if err != nil {
		return result, err
	}
	if written == nil {
		return result, fmt.Errorf("sync %s %s: row missing after write", in.Entity, in.ID)
	}
	version := written.ServerVersion
	result.Status = string(syncbase.StatusApplied)
	result.ServerVersion = &version
	return result, nil
}

func rejected(result dto.PushResult, reject *syncbase.RejectError) dto.PushResult {
	result.Status = string(syncbase.StatusRejected)
	result.Error = &dto.PushError{
		Code:      string(reject.Code),
		Message:   reject.Message,
		Retryable: reject.Retryable,
		Fields:    reject.Fields,
	}
	return result
}
