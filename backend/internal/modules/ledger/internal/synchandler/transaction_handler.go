// Package synchandler adapts the ledger service to the sync protocol.
package synchandler

import (
	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewTransactionHandler builds the sync handler of transactions.
func NewTransactionHandler(repo *repository.TransactionRepository, svc *service.TransactionService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.Transaction]("transactions", repo.Repository, svc.Upsert, svc.Delete)
}
