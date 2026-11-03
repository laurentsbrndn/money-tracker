package service

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"slices"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"

	"moneytracker/internal/modules/billing/internal/client"
	"moneytracker/internal/modules/billing/internal/dto"
	"moneytracker/internal/modules/billing/internal/model"
	"moneytracker/internal/modules/billing/internal/repository"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/idgen"
)

// PremiumEndedHandler is called when a user's premium goes from active to inactive. The
// composition root implements it with ledger.PauseRules (billing may not import ledger).
type PremiumEndedHandler interface {
	OnPremiumEnded(ctx context.Context, userID uuid.UUID) error
}

// SubscriberReader reads the current RevenueCat state of a user.
type SubscriberReader interface {
	Configured() bool
	GetSubscriber(ctx context.Context, appUserID string) (client.Subscriber, error)
}

const (
	// maxErrorLength bounds the error text kept on a billing event.
	maxErrorLength = 1000
	// processTimeout bounds the processing of one webhook (lock wait included). RevenueCat waits
	// 60 seconds for the answer; an event that takes longer is answered 500 and sent again.
	processTimeout = 20 * time.Second
	// recordTimeout bounds writing the outcome on the event, which must work even when the
	// processing deadline has passed.
	recordTimeout = 5 * time.Second
)

// ErrTransient marks a failure that may go away on its own (database error, lock wait that
// timed out, a panic, an unreadable state). The webhook answers 500 so RevenueCat sends the
// event again. Anything else is permanent: resending the same event cannot change the outcome.
var ErrTransient = errors.New("transient webhook failure")

// permanentError wraps a failure that a retry cannot fix.
type permanentError struct{ err error }

func (e permanentError) Error() string { return e.err.Error() }
func (e permanentError) Unwrap() error { return e.err }

// WebhookService handles RevenueCat webhooks.
//
// A webhook only says that something changed. Webhooks can arrive twice, late, or out of
// order, so the service reads the subscriber's current state from the RevenueCat REST API
// (inside the user's lock, so reads and writes keep the same order) and writes that. When the
// API cannot be reached it falls back to the fields of the event itself, and then ignores an
// event older than one already handled for the user.
type WebhookService struct {
	db     *database.TxManager
	clock  clock.Clock
	events *repository.BillingEventRepository
	ents   *repository.EntitlementRepository
	subs   *repository.SubscriptionRepository
	rc     SubscriberReader
	ended  PremiumEndedHandler
	log    *slog.Logger
}

// NewWebhookService builds the service.
func NewWebhookService(
	db *database.TxManager, clk clock.Clock,
	events *repository.BillingEventRepository, ents *repository.EntitlementRepository,
	subs *repository.SubscriptionRepository, rc SubscriberReader, ended PremiumEndedHandler,
	log *slog.Logger,
) *WebhookService {
	return &WebhookService{db: db, clock: clk, events: events, ents: ents, subs: subs, rc: rc, ended: ended, log: log}
}

// Handle stores the event once and processes it. A permanent outcome (unknown user, ignored
// event, duplicate already handled, a state that cannot be derived) is answered 200. A
// transient failure is recorded on the event and returned wrapped in ErrTransient, so the
// handler answers 500 and RevenueCat sends the event again; the retry is processed again
// because the event has no processed_at, and processing is idempotent. Failing to store the
// event is returned as is (also a 500).
func (s *WebhookService) Handle(ctx context.Context, raw []byte, hook dto.RevenueCatWebhook) error {
	ev := hook.Event
	ts := time.UnixMilli(*ev.EventTimestampMs).UTC()
	users := resolveUsers(ev)

	row := &model.BillingEvent{
		ID: ev.ID, Type: ev.Type, EventTimestamp: ts,
		Payload: datatypes.JSON(raw), ReceivedAt: s.clock.Now(),
	}
	if len(users) > 0 {
		row.UserID = &users[0]
	}
	inserted, err := s.events.Insert(ctx, row)
	if err != nil {
		return err
	}
	if !inserted {
		// A duplicate delivery. It is skipped once handled; one that failed earlier is retried.
		existing, err := s.events.Get(ctx, ev.ID)
		if err != nil {
			return err
		}
		if existing != nil && existing.ProcessedAt != nil {
			return nil
		}
		if existing != nil && existing.UserID == nil && len(users) > 0 {
			if err := s.events.SetUser(ctx, ev.ID, users[0]); err != nil {
				return err
			}
		}
	}

	if ignoredEvent(ev.Type) {
		return s.finish(ctx, ev.ID, nil)
	}
	if len(users) == 0 {
		// Anonymous or unknown app user: stored, not processed.
		s.log.InfoContext(ctx, "billing: event has no known user", "event_id", ev.ID, "type", ev.Type)
		return nil
	}

	procCtx, cancel := context.WithTimeout(ctx, processTimeout)
	defer cancel()
	var errs []error
	transient := false
	for _, userID := range users {
		if err := s.syncUserSafely(procCtx, userID, ev, ts); err != nil {
			var perm permanentError
			if !errors.As(err, &perm) {
				transient = true
			}
			s.log.ErrorContext(ctx, "billing: event failed", "event_id", ev.ID, "type", ev.Type, "user_id", userID, "transient", !errors.As(err, &perm), "error", err)
			errs = append(errs, fmt.Errorf("user %s: %w", userID, err))
		}
	}
	procErr := errors.Join(errs...)
	if err := s.finish(ctx, ev.ID, procErr); err != nil {
		return err
	}
	if transient {
		return fmt.Errorf("%w: %w", ErrTransient, procErr)
	}
	return nil
}

// syncUserSafely runs syncUser and turns a panic into an (transient) error, so the failure is
// recorded on the event instead of escaping to the global recover middleware.
func (s *WebhookService) syncUserSafely(ctx context.Context, userID uuid.UUID, ev dto.RevenueCatEvent, ts time.Time) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = fmt.Errorf("panic while processing event: %v", r)
		}
	}()
	return s.syncUser(ctx, userID, ev, ts)
}

// finish records the outcome of processing on the event. It uses its own deadline: the one of
// the processing may be the very reason the event failed.
func (s *WebhookService) finish(ctx context.Context, eventID string, procErr error) error {
	ctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), recordTimeout)
	defer cancel()
	if procErr != nil {
		msg := procErr.Error()
		if len(msg) > maxErrorLength {
			msg = msg[:maxErrorLength]
		}
		return s.events.MarkFailed(ctx, eventID, msg)
	}
	return s.events.MarkProcessed(ctx, eventID, s.clock.Now())
}

// resolveUsers returns the server users an event concerns. A transfer or redemption concerns
// every account it names; any other event concerns app_user_id, or, when that is anonymous, the
// first original id or alias that is a server user id.
func resolveUsers(ev dto.RevenueCatEvent) []uuid.UUID {
	var ids []string
	switch ev.Type {
	case evTransfer:
		ids = append(append(ids, ev.TransferredFrom...), ev.TransferredTo...)
	case evPurchaseRedeemed:
		ids = append(append(append(ids, ev.RedeemedFrom...), ev.RedeemedBy...), ev.AppUserID)
	default:
		ids = append([]string{ev.AppUserID, ev.OriginalAppUserID}, ev.Aliases...)
	}
	var users []uuid.UUID
	for _, raw := range ids {
		id, ok := parseUserID(raw)
		if !ok || slices.Contains(users, id) {
			continue
		}
		users = append(users, id)
		if ev.Type != evTransfer && ev.Type != evPurchaseRedeemed {
			break // one user per ordinary event
		}
	}
	return users
}

// parseUserID accepts only the canonical form of a server user id (RevenueCat's anonymous ids
// start with $RCAnonymousID:).
func parseUserID(raw string) (uuid.UUID, bool) {
	if len(raw) != 36 {
		return uuid.Nil, false
	}
	id, err := uuid.Parse(raw)
	if err != nil || id == uuid.Nil {
		return uuid.Nil, false
	}
	return id, true
}

// syncUser brings one user's entitlement up to date, under the user's lock.
func (s *WebhookService) syncUser(ctx context.Context, userID uuid.UUID, ev dto.RevenueCatEvent, ts time.Time) error {
	return s.db.WithTx(ctx, func(ctx context.Context) error {
		if err := database.LockUser(ctx, s.db.DB(ctx), userID); err != nil {
			return err
		}
		now := s.clock.Now()
		st, ok, err := s.resolveState(ctx, userID, ev, ts, now)
		if err != nil || !ok {
			return err
		}
		return s.apply(ctx, userID, st, ev, now)
	})
}

// resolveState returns the state to write; ok is false when the event changes nothing.
func (s *WebhookService) resolveState(ctx context.Context, userID uuid.UUID, ev dto.RevenueCatEvent, ts, now time.Time) (State, bool, error) {
	if s.rc != nil && s.rc.Configured() {
		sub, err := s.rc.GetSubscriber(ctx, userID.String())
		if err == nil {
			return StateFromSubscriber(sub, now), true, nil
		}
		s.log.WarnContext(ctx, "billing: revenuecat lookup failed, using the event", "event_id", ev.ID, "user_id", userID, "error", err)
		if ev.Type == evTransfer || ev.Type == evPurchaseRedeemed {
			// No fallback exists for these: the lookup must be retried.
			return State{}, false, fmt.Errorf("read subscriber: %w", err)
		}
	}

	if ev.Type == evTransfer || ev.Type == evPurchaseRedeemed {
		// Without an API key the state of a transfer can never be derived: a retry changes nothing.
		return State{}, false, permanentError{errors.New("state of a transfer needs the revenuecat api")}
	}
	if len(ev.EntitlementIDs) > 0 && !slices.Contains(ev.EntitlementIDs, model.EntitlementPremium) {
		return State{}, false, nil // another entitlement
	}
	newer, err := s.events.NewerProcessedExists(ctx, userID, ts, ev.ID, stateEventTypes)
	if err != nil {
		return State{}, false, err
	}
	if newer {
		s.log.InfoContext(ctx, "billing: event is older than one already handled", "event_id", ev.ID, "user_id", userID)
		return State{}, false, nil
	}
	st, ok := StateFromEvent(ev, now)
	if ok && ev.Type == evTemporaryGrant {
		// A temporary grant never shortens or replaces real access.
		prev, err := s.ents.Get(ctx, userID, model.EntitlementPremium)
		if err != nil {
			return State{}, false, err
		}
		if effective(prev, now) {
			return State{}, false, nil
		}
	}
	return st, ok, nil
}

// apply writes the subscription and the entitlement, and tells the ledger when premium ended.
func (s *WebhookService) apply(ctx context.Context, userID uuid.UUID, st State, ev dto.RevenueCatEvent, now time.Time) error {
	prev, err := s.ents.Get(ctx, userID, model.EntitlementPremium)
	if err != nil {
		return err
	}
	if prev == nil && !st.Premium && !st.HasSubscription {
		return nil // nothing was ever granted
	}

	var subID *uuid.UUID
	switch {
	case st.HasSubscription:
		id, err := s.saveSubscription(ctx, userID, st, ev, now)
		if err != nil {
			return err
		}
		subID = &id
	case prev != nil && prev.SubscriptionID != nil && !st.Premium:
		// Keep the history link while the user owns that subscription.
		if sub, err := s.subs.Get(ctx, *prev.SubscriptionID); err != nil {
			return err
		} else if sub != nil && sub.UserID == userID {
			subID = prev.SubscriptionID
		}
	}

	if err := s.ents.Save(ctx, &model.Entitlement{
		UserID: userID, EntitlementKey: model.EntitlementPremium, IsActive: st.Premium,
		ExpiresAt: st.AccessEnd, SubscriptionID: subID, UpdatedAt: now,
	}); err != nil {
		return err
	}

	if prev != nil && prev.IsActive && !st.Premium && s.ended != nil {
		if err := s.ended.OnPremiumEnded(ctx, userID); err != nil {
			return fmt.Errorf("premium ended handler: %w", err)
		}
	}
	return nil
}

// saveSubscription upserts the subscription of the state and returns its id.
func (s *WebhookService) saveSubscription(ctx context.Context, userID uuid.UUID, st State, ev dto.RevenueCatEvent, now time.Time) (uuid.UUID, error) {
	orig, err := s.resolveOriginal(ctx, userID, st, ev)
	if err != nil {
		return uuid.Nil, err
	}
	existing, err := s.subs.FindByOriginal(ctx, st.Store, orig)
	if err != nil {
		return uuid.Nil, err
	}
	sub := &model.Subscription{
		UserID: userID, Store: st.Store, ProductID: st.ProductID, Status: st.Status,
		PeriodType: st.PeriodType, CurrentPeriodStart: st.PeriodStart, CurrentPeriodEnd: st.PeriodEnd,
		WillRenew: st.WillRenew, OriginalTransactionID: orig, Environment: st.Environment,
		CreatedAt: now, UpdatedAt: now,
	}
	if existing != nil {
		sub.ID, sub.CreatedAt = existing.ID, existing.CreatedAt
	} else if sub.ID, err = idgen.NewV7(); err != nil {
		return uuid.Nil, err
	}
	if err := s.subs.Save(ctx, sub); err != nil {
		return uuid.Nil, err
	}
	if existing != nil && existing.UserID != userID {
		if err := s.ents.ClearSubscription(ctx, sub.ID, userID); err != nil {
			return uuid.Nil, err
		}
	}
	return sub.ID, nil
}

// resolveOriginal finds the original transaction id that keys the subscription row, so every
// renewal updates one row. The REST API only returns the latest transaction id, so the id comes
// from the event when it is about this product, else from the user's existing row, else from the
// latest transaction.
func (s *WebhookService) resolveOriginal(ctx context.Context, userID uuid.UUID, st State, ev dto.RevenueCatEvent) (string, error) {
	if st.OriginalTransactionID != "" {
		return st.OriginalTransactionID, nil
	}
	if ev.OriginalTransaction != "" && (ev.ProductID == st.ProductID || ev.NewProductID == st.ProductID) &&
		(normalizeStore(ev.Store) == st.Store || ev.Store == "") {
		return ev.OriginalTransaction, nil
	}
	existing, err := s.subs.FindLatest(ctx, userID, st.Store, st.ProductID)
	if err != nil {
		return "", err
	}
	if existing != nil {
		return existing.OriginalTransactionID, nil
	}
	// A transfer names the accounts it takes the subscription from: keep its original id, so
	// the row changes owner instead of a second row being created.
	for _, raw := range append(append([]string(nil), ev.TransferredFrom...), ev.RedeemedFrom...) {
		from, ok := parseUserID(raw)
		if !ok || from == userID {
			continue
		}
		moved, err := s.subs.FindLatest(ctx, from, st.Store, st.ProductID)
		if err != nil {
			return "", err
		}
		if moved != nil {
			return moved.OriginalTransactionID, nil
		}
	}
	if st.StoreTransactionID != "" {
		return st.StoreTransactionID, nil
	}
	return strings.Join([]string{"rc", st.ProductID, userID.String()}, ":"), nil
}
