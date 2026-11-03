// Package synchandler adapts the category service to the sync protocol.
package synchandler

import (
	"moneytracker/internal/modules/category/internal/model"
	"moneytracker/internal/modules/category/internal/repository"
	"moneytracker/internal/modules/category/internal/service"
	"moneytracker/internal/platform/syncbase"
)

// Entity is the wire name of the categories entity.
const Entity = "categories"

// NewCategoryHandler builds the sync handler of categories.
func NewCategoryHandler(repo *repository.CategoryRepository, svc *service.CategoryService) syncbase.Handler {
	return syncbase.NewEntityHandler[model.Category](Entity, repo.Repository, svc.Upsert, svc.Delete)
}
