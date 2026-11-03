// Package synchandler adapts the wallet services to the sync protocol.
package synchandler

import (
	"moneytracker/internal/modules/wallet/internal/model"
	"moneytracker/internal/modules/wallet/internal/repository"
	"moneytracker/internal/modules/wallet/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewAccountHandler builds the sync handler of accounts.
func NewAccountHandler(repo *repository.AccountRepository, svc *service.AccountService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.Account]("accounts", repo.Repository, svc.Upsert, svc.Delete)
}
