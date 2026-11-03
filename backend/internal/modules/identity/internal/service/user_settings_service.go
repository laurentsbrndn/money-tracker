package service

import (
	"context"
	"regexp"

	"github.com/google/uuid"

	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/syncbase"
)

var reminderTimePattern = regexp.MustCompile(`^([01][0-9]|2[0-3]):[0-5][0-9]$`)

const (
	weekStartMonday = 1
	weekStartSunday = 7
)

// UserSettingsService validates and stores the user's settings row (docs/BUSINESS_RULES.md §6).
// The row id equals the user id; the row cannot be deleted.
type UserSettingsService struct {
	repo  *repository.UserSettingsRepository
	clock clock.Clock
}

// NewUserSettingsService builds the service.
func NewUserSettingsService(repo *repository.UserSettingsRepository, clk clock.Clock) *UserSettingsService {
	return &UserSettingsService{repo: repo, clock: clk}
}

// Upsert validates pushed settings and writes the whole row.
func (s *UserSettingsService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[UserSettingsRow](c.Data)
	if rej != nil {
		return rej
	}
	if in.ID != c.ID {
		return syncbase.InvalidField("id", "id di data harus sama dengan id entri")
	}
	if c.ID != userID {
		return syncbase.InvalidField("id", "id pengaturan harus sama dengan id user")
	}
	if in.DeletedAt != nil {
		return syncbase.InvalidField("deleted_at", "upsert tidak boleh berisi deleted_at; gunakan op delete")
	}
	if err := validateTimezone(in.Timezone); err != nil {
		return syncbase.InvalidField("timezone", "bukan nama timezone IANA yang valid")
	}
	if in.Currency != "IDR" {
		return syncbase.InvalidField("currency", "hanya IDR yang didukung")
	}
	if *in.WeekStart != weekStartMonday && *in.WeekStart != weekStartSunday {
		return syncbase.InvalidField("week_start", "harus 1 (Senin) atau 7 (Minggu)")
	}
	if in.DailyReminderTime != nil && !reminderTimePattern.MatchString(*in.DailyReminderTime) {
		return syncbase.InvalidField("daily_reminder_time", "harus berformat HH:MM")
	}

	row := &model.UserSettings{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		Timezone:                 in.Timezone,
		Currency:                 in.Currency,
		WeekStart:                int16(*in.WeekStart),
		Theme:                    in.Theme,
		DailyReminderTime:        in.DailyReminderTime,
		ReconcileReminderEnabled: *in.ReconcileReminderEnabled,
		BudgetAlertEnabled:       *in.BudgetAlertEnabled,
		HideAmounts:              *in.HideAmounts,
	}
	return s.repo.Save(ctx, row, s.clock.Now())
}

// Delete always rejects: the settings row is permanent.
func (s *UserSettingsService) Delete(_ context.Context, _ uuid.UUID, _ syncbase.Change) error {
	return syncbase.Invalid("pengaturan tidak dapat dihapus")
}

// CreateDefault creates the settings row of a new user with the timezone from registration
// (docs/DATA_MODEL.md §9). Run it inside the registration transaction.
func (s *UserSettingsService) CreateDefault(ctx context.Context, userID uuid.UUID, timezone string) error {
	now := s.clock.Now()
	row := &model.UserSettings{
		Columns: syncbase.Columns{
			ID: userID, UserID: userID, CreatedAt: syncbase.NewTime(now), UpdatedAt: syncbase.NewTime(now),
		},
		Timezone:                 timezone,
		Currency:                 "IDR",
		WeekStart:                weekStartMonday,
		Theme:                    "system",
		ReconcileReminderEnabled: true,
		BudgetAlertEnabled:       true,
	}
	return s.repo.Save(ctx, row, now)
}
