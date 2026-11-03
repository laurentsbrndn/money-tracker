// Package synchandler adapts the user settings service to the sync protocol.
package synchandler

import (
	"moneytracker/internal/modules/identity/internal/model"
	"moneytracker/internal/modules/identity/internal/repository"
	"moneytracker/internal/modules/identity/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewUserSettingsHandler builds the sync handler of user_settings.
func NewUserSettingsHandler(repo *repository.UserSettingsRepository, svc *service.UserSettingsService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.UserSettings]("user_settings", repo.Repository, svc.Upsert, svc.Delete)
}
