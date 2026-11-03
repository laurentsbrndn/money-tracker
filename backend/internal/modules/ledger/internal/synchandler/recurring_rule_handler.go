package synchandler

import (
	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/modules/ledger/internal/repository"
	"moneytracker/internal/modules/ledger/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewRecurringRuleHandler builds the sync handler of recurring rules.
func NewRecurringRuleHandler(repo *repository.RecurringRuleRepository, svc *service.RecurringRuleService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.RecurringRule]("recurring_rules", repo.Repository, svc.Upsert, svc.Delete)
}
