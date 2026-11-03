// Package synchandler adapts the budget service to the sync protocol.
package synchandler

import (
	"moneytracker/internal/modules/budget/internal/model"
	"moneytracker/internal/modules/budget/internal/repository"
	"moneytracker/internal/modules/budget/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// NewBudgetGoalHandler builds the sync handler of budget goals.
func NewBudgetGoalHandler(repo *repository.BudgetGoalRepository, svc *service.BudgetGoalService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.BudgetGoal]("budget_goals", repo.Repository, svc.Upsert, svc.Delete)
}
