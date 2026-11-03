package repository

import (
	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/platform/database"
	"moneytracker/internal/platform/syncbase"
)

// UserSettingsRepository stores the user_settings [sync] rows.
type UserSettingsRepository struct {
	*syncbase.Repository[model.UserSettings, *model.UserSettings]
}

// NewUserSettingsRepository builds the repository.
func NewUserSettingsRepository(db *database.TxManager) *UserSettingsRepository {
	return &UserSettingsRepository{Repository: syncbase.NewRepository[model.UserSettings](db)}
}
