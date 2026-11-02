package migrations

import (
	"time"

	"github.com/go-gormigrate/gormigrate/v2"
	"github.com/google/uuid"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

// All returns every migration in order. Migrations that have run must never be edited;
// add a new entry at the end instead (ID format YYYYMMDDNNNN_description).
//
// Each migration declares its own snapshot structs so that later changes to application
// models cannot alter what an old migration does.
func All() []*gormigrate.Migration {
	return []*gormigrate.Migration{
		{
			ID:       "202611020001_init",
			Migrate:  migrateInit,
			Rollback: rollbackInit,
		},
	}
}

func migrateInit(tx *gorm.DB) error {
	// Sequence shared by every [sync] table. GORM's Migrator has no sequence API.
	if err := tx.Exec("CREATE SEQUENCE sync_version_seq AS bigint START WITH 1").Error; err != nil {
		return err
	}

	// ---- identity ----

	type user struct {
		ID                  uuid.UUID  `gorm:"type:uuid;primaryKey"`
		Email               *string    `gorm:"type:varchar(254);uniqueIndex:idx_users_email"`
		EmailVerifiedAt     *time.Time `gorm:"type:timestamptz"`
		PasswordHash        *string    `gorm:"type:text"`
		Name                string     `gorm:"type:varchar(100);not null"`
		Status              string     `gorm:"type:varchar(16);not null;default:active"`
		FailedLoginCount    int        `gorm:"type:integer;not null;default:0"`
		LockedUntil         *time.Time `gorm:"type:timestamptz"`
		DeletionRequestedAt *time.Time `gorm:"type:timestamptz"`
		CreatedAt           time.Time  `gorm:"type:timestamptz;not null;default:now()"`
		UpdatedAt           time.Time  `gorm:"type:timestamptz;not null;default:now()"`
	}

	type authIdentity struct {
		ID              uuid.UUID `gorm:"type:uuid;primaryKey"`
		UserID          uuid.UUID `gorm:"type:uuid;not null;index:idx_auth_identities_user"`
		User            user      `gorm:"foreignKey:UserID;references:ID;constraint:OnDelete:CASCADE"`
		Provider        string    `gorm:"type:varchar(16);not null;uniqueIndex:idx_auth_identities_provider_subject,priority:1"`
		ProviderSubject string    `gorm:"type:varchar(255);not null;uniqueIndex:idx_auth_identities_provider_subject,priority:2"`
		Email           *string   `gorm:"type:varchar(254)"`
		CreatedAt       time.Time `gorm:"type:timestamptz;not null"`
	}

	type refreshToken struct {
		ID         uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID     uuid.UUID  `gorm:"type:uuid;not null;index:idx_refresh_tokens_user"`
		User       user       `gorm:"foreignKey:UserID;references:ID;constraint:OnDelete:CASCADE"`
		FamilyID   uuid.UUID  `gorm:"type:uuid;not null;index:idx_refresh_tokens_family"`
		TokenHash  string     `gorm:"type:char(64);not null;uniqueIndex:idx_refresh_tokens_token_hash"`
		DeviceID   string     `gorm:"type:varchar(64);not null"`
		DeviceName *string    `gorm:"type:varchar(100)"`
		ExpiresAt  time.Time  `gorm:"type:timestamptz;not null"`
		RotatedAt  *time.Time `gorm:"type:timestamptz"`
		RevokedAt  *time.Time `gorm:"type:timestamptz"`
		CreatedAt  time.Time  `gorm:"type:timestamptz;not null"`
	}

	type verificationToken struct {
		ID        uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID    uuid.UUID  `gorm:"type:uuid;not null;index:idx_verification_tokens_user_purpose,priority:1"`
		User      user       `gorm:"foreignKey:UserID;references:ID;constraint:OnDelete:CASCADE"`
		Purpose   string     `gorm:"type:varchar(32);not null;index:idx_verification_tokens_user_purpose,priority:2"`
		CodeHash  string     `gorm:"type:char(64);not null"`
		Attempts  int16      `gorm:"type:smallint;not null;default:0"`
		ExpiresAt time.Time  `gorm:"type:timestamptz;not null"`
		UsedAt    *time.Time `gorm:"type:timestamptz"`
		CreatedAt time.Time  `gorm:"type:timestamptz;not null;index:idx_verification_tokens_user_purpose,priority:3"`
	}

	type userSetting struct {
		ID                       uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID                   uuid.UUID  `gorm:"type:uuid;not null;index:idx_user_settings_user_version,priority:1"`
		CreatedAt                time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt                time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt                *time.Time `gorm:"type:timestamptz"`
		ServerVersion            int64      `gorm:"type:bigint;not null;index:idx_user_settings_user_version,priority:2"`
		ServerUpdatedAt          time.Time  `gorm:"type:timestamptz;not null"`
		Timezone                 string     `gorm:"type:varchar(64);not null;default:Asia/Jakarta"`
		Currency                 string     `gorm:"type:char(3);not null;default:IDR"`
		WeekStart                int16      `gorm:"type:smallint;not null;default:1"`
		Theme                    string     `gorm:"type:varchar(8);not null;default:system"`
		DailyReminderTime        *string    `gorm:"type:varchar(5)"`
		ReconcileReminderEnabled bool       `gorm:"not null;default:true"`
		BudgetAlertEnabled       bool       `gorm:"not null;default:true"`
		HideAmounts              bool       `gorm:"not null;default:false"`
	}

	// ---- category ----

	type category struct {
		ID                uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID            uuid.UUID  `gorm:"type:uuid;not null;index:idx_categories_user_version,priority:1;index:idx_categories_user_type,priority:1"`
		CreatedAt         time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt         time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt         *time.Time `gorm:"type:timestamptz"`
		ServerVersion     int64      `gorm:"type:bigint;not null;index:idx_categories_user_version,priority:2"`
		ServerUpdatedAt   time.Time  `gorm:"type:timestamptz;not null"`
		Type              string     `gorm:"type:varchar(8);not null;index:idx_categories_user_type,priority:2"`
		Name              string     `gorm:"type:varchar(50);not null"`
		Icon              string     `gorm:"type:varchar(50);not null"`
		Color             string     `gorm:"type:varchar(7);not null"`
		DefaultAllocation *string    `gorm:"type:varchar(8)"`
		SortOrder         int        `gorm:"type:integer;not null"`
		IsDefault         bool       `gorm:"not null"`
		IsHidden          bool       `gorm:"not null"`
		ArchivedAt        *time.Time `gorm:"type:timestamptz"`
	}

	// ---- wallet ----

	type account struct {
		ID              uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID          uuid.UUID  `gorm:"type:uuid;not null;index:idx_accounts_user_version,priority:1"`
		CreatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt       *time.Time `gorm:"type:timestamptz"`
		ServerVersion   int64      `gorm:"type:bigint;not null;index:idx_accounts_user_version,priority:2"`
		ServerUpdatedAt time.Time  `gorm:"type:timestamptz;not null"`
		Name            string     `gorm:"type:varchar(50);not null"`
		Type            string     `gorm:"type:varchar(16);not null"`
		ProviderKey     *string    `gorm:"type:varchar(32)"`
		Currency        string     `gorm:"type:char(3);not null"`
		OpeningBalance  int64      `gorm:"type:bigint;not null"`
		OpeningDate     time.Time  `gorm:"type:date;not null"`
		IncludeInTotal  bool       `gorm:"not null;default:true"`
		SortOrder       int        `gorm:"type:integer;not null"`
		ArchivedAt      *time.Time `gorm:"type:timestamptz"`
	}

	type balanceSnapshot struct {
		ID              uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID          uuid.UUID  `gorm:"type:uuid;not null;index:idx_balance_snapshots_user_version,priority:1;index:idx_balance_snapshots_user_account_date,priority:1"`
		CreatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt       *time.Time `gorm:"type:timestamptz"`
		ServerVersion   int64      `gorm:"type:bigint;not null;index:idx_balance_snapshots_user_version,priority:2"`
		ServerUpdatedAt time.Time  `gorm:"type:timestamptz;not null"`
		AccountID       uuid.UUID  `gorm:"type:uuid;not null;index:idx_balance_snapshots_user_account_date,priority:2"`
		Account         account    `gorm:"foreignKey:AccountID;references:ID"`
		SnapshotDate    time.Time  `gorm:"type:date;not null;index:idx_balance_snapshots_user_account_date,priority:3"`
		Amount          int64      `gorm:"type:bigint;not null"`
		Note            *string    `gorm:"type:varchar(255)"`
	}

	// ---- ledger ----

	type transaction struct {
		ID                  uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID              uuid.UUID  `gorm:"type:uuid;not null;index:idx_transactions_user_version,priority:1;index:idx_transactions_user_date,priority:1;index:idx_transactions_user_account_date,priority:1;index:idx_transactions_user_to_account,priority:1;index:idx_transactions_user_recurring_rule,priority:1"`
		CreatedAt           time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt           time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt           *time.Time `gorm:"type:timestamptz"`
		ServerVersion       int64      `gorm:"type:bigint;not null;index:idx_transactions_user_version,priority:2"`
		ServerUpdatedAt     time.Time  `gorm:"type:timestamptz;not null"`
		Type                string     `gorm:"type:varchar(16);not null"`
		Status              string     `gorm:"type:varchar(24);not null;default:posted"`
		TransactionDate     time.Time  `gorm:"type:date;not null;index:idx_transactions_user_date,priority:2;index:idx_transactions_user_account_date,priority:3"`
		Amount              int64      `gorm:"type:bigint;not null"`
		Currency            string     `gorm:"type:char(3);not null"`
		AccountID           uuid.UUID  `gorm:"type:uuid;not null;index:idx_transactions_user_account_date,priority:2"`
		ToAccountID         *uuid.UUID `gorm:"type:uuid;index:idx_transactions_user_to_account,priority:2"`
		CategoryID          *uuid.UUID `gorm:"type:uuid"`
		Allocation          *string    `gorm:"type:varchar(8)"`
		Source              *string    `gorm:"type:varchar(100)"`
		Note                *string    `gorm:"type:varchar(255)"`
		LinkedTransactionID *uuid.UUID `gorm:"type:uuid"`
		RecurringRuleID     *uuid.UUID `gorm:"type:uuid;index:idx_transactions_user_recurring_rule,priority:2"`
	}

	type recurringRule struct {
		ID                uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID            uuid.UUID  `gorm:"type:uuid;not null;index:idx_recurring_rules_user_version,priority:1"`
		CreatedAt         time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt         time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt         *time.Time `gorm:"type:timestamptz"`
		ServerVersion     int64      `gorm:"type:bigint;not null;index:idx_recurring_rules_user_version,priority:2"`
		ServerUpdatedAt   time.Time  `gorm:"type:timestamptz;not null"`
		Type              string     `gorm:"type:varchar(16);not null"`
		Amount            int64      `gorm:"type:bigint;not null"`
		AccountID         uuid.UUID  `gorm:"type:uuid;not null"`
		ToAccountID       *uuid.UUID `gorm:"type:uuid"`
		CategoryID        *uuid.UUID `gorm:"type:uuid"`
		Allocation        *string    `gorm:"type:varchar(8)"`
		Source            *string    `gorm:"type:varchar(100)"`
		Note              *string    `gorm:"type:varchar(255)"`
		Frequency         string     `gorm:"type:varchar(8);not null"`
		IntervalCount     int16      `gorm:"type:smallint;not null;default:1"`
		DayOfWeek         *int16     `gorm:"type:smallint"`
		DayOfMonth        *int16     `gorm:"type:smallint"`
		MonthOfYear       *int16     `gorm:"type:smallint"`
		StartDate         time.Time  `gorm:"type:date;not null"`
		EndDate           *time.Time `gorm:"type:date"`
		Mode              string     `gorm:"type:varchar(8);not null"`
		IsPaused          bool       `gorm:"not null"`
		LastGeneratedDate *time.Time `gorm:"type:date"`
	}

	// ---- budget ----

	type budgetGoal struct {
		ID              uuid.UUID  `gorm:"type:uuid;primaryKey"`
		UserID          uuid.UUID  `gorm:"type:uuid;not null;index:idx_budget_goals_user_version,priority:1;index:idx_budget_goals_user_effective_month,priority:1"`
		CreatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		UpdatedAt       time.Time  `gorm:"type:timestamptz;not null"`
		DeletedAt       *time.Time `gorm:"type:timestamptz"`
		ServerVersion   int64      `gorm:"type:bigint;not null;index:idx_budget_goals_user_version,priority:2"`
		ServerUpdatedAt time.Time  `gorm:"type:timestamptz;not null"`
		EffectiveMonth  time.Time  `gorm:"type:date;not null;index:idx_budget_goals_user_effective_month,priority:2"`
		NeedsPct        int16      `gorm:"type:smallint;not null"`
		WantsPct        int16      `gorm:"type:smallint;not null"`
		SavingsPct      int16      `gorm:"type:smallint;not null"`
		PlannedIncome   *int64     `gorm:"type:bigint"`
	}

	// ---- sync ----

	type syncIdempotencyKey struct {
		UserID         uuid.UUID      `gorm:"type:uuid;primaryKey"`
		IdempotencyKey string         `gorm:"type:varchar(64);primaryKey"`
		Response       datatypes.JSON `gorm:"type:jsonb;not null"`
		CreatedAt      time.Time      `gorm:"type:timestamptz;not null"`
	}

	// ---- billing ----

	type subscription struct {
		ID                    uuid.UUID `gorm:"type:uuid;primaryKey"`
		UserID                uuid.UUID `gorm:"type:uuid;not null;index:idx_subscriptions_user"`
		Store                 string    `gorm:"type:varchar(16);not null;uniqueIndex:idx_subscriptions_store_original_transaction,priority:1"`
		ProductID             string    `gorm:"type:varchar(100);not null"`
		Status                string    `gorm:"type:varchar(24);not null"`
		PeriodType            string    `gorm:"type:varchar(16);not null"`
		CurrentPeriodStart    time.Time `gorm:"type:timestamptz;not null"`
		CurrentPeriodEnd      time.Time `gorm:"type:timestamptz;not null"`
		WillRenew             bool      `gorm:"not null"`
		OriginalTransactionID string    `gorm:"type:varchar(100);not null;uniqueIndex:idx_subscriptions_store_original_transaction,priority:2"`
		Environment           string    `gorm:"type:varchar(12);not null"`
		CreatedAt             time.Time `gorm:"type:timestamptz;not null"`
		UpdatedAt             time.Time `gorm:"type:timestamptz;not null"`
	}

	type entitlement struct {
		UserID         uuid.UUID     `gorm:"type:uuid;primaryKey"`
		EntitlementKey string        `gorm:"type:varchar(32);primaryKey"`
		IsActive       bool          `gorm:"not null"`
		ExpiresAt      *time.Time    `gorm:"type:timestamptz"`
		SubscriptionID *uuid.UUID    `gorm:"type:uuid"`
		Subscription   *subscription `gorm:"foreignKey:SubscriptionID;references:ID"`
		UpdatedAt      time.Time     `gorm:"type:timestamptz;not null"`
	}

	type billingEvent struct {
		ID             string         `gorm:"type:varchar(100);primaryKey"`
		UserID         *uuid.UUID     `gorm:"type:uuid"`
		Type           string         `gorm:"type:varchar(50);not null"`
		EventTimestamp time.Time      `gorm:"type:timestamptz;not null"`
		Payload        datatypes.JSON `gorm:"type:jsonb;not null"`
		ReceivedAt     time.Time      `gorm:"type:timestamptz;not null"`
		ProcessedAt    *time.Time     `gorm:"type:timestamptz"`
		Error          *string        `gorm:"type:text"`
	}

	// Parents before children so foreign keys can be created inline.
	tables := []any{
		&user{}, &authIdentity{}, &refreshToken{}, &verificationToken{}, &userSetting{},
		&category{},
		&account{}, &balanceSnapshot{},
		&transaction{}, &recurringRule{},
		&budgetGoal{},
		&syncIdempotencyKey{},
		&subscription{}, &entitlement{}, &billingEvent{},
	}
	for _, t := range tables {
		if err := tx.Migrator().CreateTable(t); err != nil {
			return err
		}
	}
	return nil
}

func rollbackInit(tx *gorm.DB) error {
	// Children before parents.
	err := tx.Migrator().DropTable(
		"billing_events", "entitlements", "subscriptions",
		"sync_idempotency_keys",
		"budget_goals",
		"recurring_rules", "transactions",
		"balance_snapshots", "accounts",
		"categories",
		"user_settings", "verification_tokens", "refresh_tokens", "auth_identities", "users",
	)
	if err != nil {
		return err
	}
	return tx.Exec("DROP SEQUENCE IF EXISTS sync_version_seq").Error
}
