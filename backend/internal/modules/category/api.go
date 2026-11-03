// Package category owns the categories table. Other modules use only this file.
package category

import (
	"context"

	"github.com/google/uuid"

	"moneytracker/internal/modules/category/internal/service"
)

// Category is the public view of a category.
type Category = service.Category

// ErrNotFound is returned by Categories.Get for an unknown category.
var ErrNotFound = service.ErrNotFound

// ReferenceChecker reports whether live transactions still use a category. ledger implements
// it; the composition root injects it.
type ReferenceChecker = service.ReferenceChecker

// Categories is the public interface of the module.
type Categories interface {
	// Get returns the user's category (deleted ones included, flagged) or ErrNotFound.
	Get(ctx context.Context, userID, id uuid.UUID) (Category, error)
	// SeedDefaults creates the default categories (docs/BUSINESS_RULES.md §2.1).
	SeedDefaults(ctx context.Context, userID uuid.UUID) error
	// CountCustom counts the user's live custom categories.
	CountCustom(ctx context.Context, userID uuid.UUID) (int, error)
}
