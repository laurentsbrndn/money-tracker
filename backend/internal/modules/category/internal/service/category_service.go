// Package service holds the business rules of the category module.
package service

import (
	"context"
	"errors"
	"regexp"

	"github.com/google/uuid"

	"moneytracker/internal/modules/billing"
	"moneytracker/internal/modules/category/internal/dto"
	"moneytracker/internal/modules/category/internal/model"
	"moneytracker/internal/modules/category/internal/repository"
	"moneytracker/internal/platform/clock"
	"moneytracker/internal/platform/idgen"
	"moneytracker/internal/platform/syncbase"
)

var colorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// ErrNotFound is returned by Get for an unknown category.
var ErrNotFound = errors.New("category not found")

// ReferenceChecker tells whether live transactions still use a category. It is implemented by
// ledger and injected by the composition root (ledger depends on category, not the reverse).
type ReferenceChecker interface {
	HasActiveReferences(ctx context.Context, userID, id uuid.UUID) (bool, error)
}

// Category is the public view of a category for other modules.
type Category struct {
	ID         uuid.UUID
	Type       string
	IsArchived bool
	IsDeleted  bool
}

// CategoryService validates and stores categories (docs/BUSINESS_RULES.md §6, §7).
type CategoryService struct {
	repo    *repository.CategoryRepository
	billing billing.Entitlements
	refs    ReferenceChecker
	clock   clock.Clock
}

// NewCategoryService builds the service.
func NewCategoryService(repo *repository.CategoryRepository, bill billing.Entitlements, refs ReferenceChecker, clk clock.Clock) *CategoryService {
	return &CategoryService{repo: repo, billing: bill, refs: refs, clock: clk}
}

// Upsert validates a pushed category and writes the whole row. Returned errors that are
// *syncbase.RejectError reject the change; others are infrastructure failures.
func (s *CategoryService) Upsert(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	in, rej := syncbase.Decode[dto.CategoryRow](c.Data)
	if rej != nil {
		return rej
	}
	if in.ID != c.ID {
		return syncbase.InvalidField("id", "id di data harus sama dengan id entri")
	}
	if in.DeletedAt != nil {
		return syncbase.InvalidField("deleted_at", "upsert tidak boleh berisi deleted_at; gunakan op delete")
	}

	existing, err := s.repo.Find(ctx, userID, c.ID)
	if err != nil {
		return err
	}
	if rej := validateFields(in, existing); rej != nil {
		return rej
	}

	taken, err := s.repo.NameTaken(ctx, userID, in.Type, in.Name, c.ID)
	if err != nil {
		return err
	}
	if taken {
		return syncbase.InvalidField("name", "nama kategori sudah dipakai")
	}

	// The custom-category limit applies when a row starts to count: a new row or a revived
	// tombstone. Plain updates are never blocked. Rows written earlier in the same push are
	// visible here because everything runs in one transaction.
	if existing == nil || existing.DeletedAt != nil {
		premium, err := s.billing.IsPremium(ctx, userID)
		if err != nil {
			return err
		}
		custom, err := s.repo.CountCustom(ctx, userID, c.ID)
		if err != nil {
			return err
		}
		if billing.CustomCategoryLimitReached(premium, custom) {
			return syncbase.PlanLimit("Batas kategori custom paket gratis tercapai")
		}
	}

	row := &model.Category{
		Columns: syncbase.Columns{
			ID:        c.ID,
			UserID:    userID,
			CreatedAt: *in.CreatedAt,
			UpdatedAt: syncbase.NewTime(c.UpdatedAt),
		},
		Type:              in.Type,
		Name:              in.Name,
		Icon:              in.Icon,
		Color:             in.Color,
		DefaultAllocation: in.DefaultAllocation,
		SortOrder:         *in.SortOrder,
		IsDefault:         *in.IsDefault,
		IsHidden:          *in.IsHidden,
		ArchivedAt:        in.ArchivedAt,
	}
	return s.repo.Save(ctx, row, s.clock.Now())
}

// Delete tombstones a category unless live transactions still use it (archive instead).
func (s *CategoryService) Delete(ctx context.Context, userID uuid.UUID, c syncbase.Change) error {
	used, err := s.refs.HasActiveReferences(ctx, userID, c.ID)
	if err != nil {
		return err
	}
	if used {
		return syncbase.Invalid("kategori masih dipakai transaksi; arsipkan saja")
	}
	return s.repo.Tombstone(ctx, userID, c.ID, syncbase.NewTime(c.UpdatedAt), s.clock.Now())
}

func validateFields(in dto.CategoryRow, existing *model.Category) *syncbase.RejectError {
	if !syncbase.TextLen(in.Name, 1, 50) {
		return syncbase.InvalidField("name", "nama harus 1-50 karakter")
	}
	if !colorPattern.MatchString(in.Color) {
		return syncbase.InvalidField("color", "warna harus berformat #RRGGBB")
	}
	switch in.Type {
	case model.TypeExpense:
		if in.DefaultAllocation == nil {
			return syncbase.InvalidField("default_allocation", "wajib diisi untuk kategori expense")
		}
	case model.TypeIncome:
		if in.DefaultAllocation != nil {
			return syncbase.InvalidField("default_allocation", "harus null untuk kategori income")
		}
	}
	// is_default marks seeded categories only; clients may neither create nor change it.
	if existing == nil && *in.IsDefault {
		return syncbase.InvalidField("is_default", "kategori baru dari client tidak boleh is_default")
	}
	if existing != nil && *in.IsDefault != existing.IsDefault {
		return syncbase.InvalidField("is_default", "is_default tidak boleh diubah")
	}
	return nil
}

// Get returns the user's category, including deleted ones, or ErrNotFound.
func (s *CategoryService) Get(ctx context.Context, userID, id uuid.UUID) (Category, error) {
	row, err := s.repo.Find(ctx, userID, id)
	if err != nil {
		return Category{}, err
	}
	if row == nil {
		return Category{}, ErrNotFound
	}
	return Category{
		ID:         row.ID,
		Type:       row.Type,
		IsArchived: row.ArchivedAt != nil,
		IsDeleted:  row.DeletedAt != nil,
	}, nil
}

// CountCustom returns the number of live custom categories.
func (s *CategoryService) CountCustom(ctx context.Context, userID uuid.UUID) (int, error) {
	return s.repo.CountCustom(ctx, userID, uuid.Nil)
}

// SeedDefaults creates the default categories of a new user (docs/DATA_MODEL.md §9). Run it
// inside the registration transaction, which holds the user lock.
func (s *CategoryService) SeedDefaults(ctx context.Context, userID uuid.UUID) error {
	now := s.clock.Now()
	position := map[string]int{}
	rows := make([]*model.Category, 0, len(defaultCategories))
	for _, d := range defaultCategories {
		id, err := idgen.NewV7()
		if err != nil {
			return err
		}
		position[d.Type]++
		row := &model.Category{
			Columns: syncbase.Columns{
				ID: id, UserID: userID, CreatedAt: syncbase.NewTime(now), UpdatedAt: syncbase.NewTime(now),
			},
			Type:      d.Type,
			Name:      d.Name,
			Icon:      d.Icon,
			Color:     d.Color,
			SortOrder: position[d.Type],
			IsDefault: true,
		}
		if d.Allocation != "" {
			allocation := d.Allocation
			row.DefaultAllocation = &allocation
		}
		rows = append(rows, row)
	}
	// One version query and one INSERT for the whole list, in list order.
	return s.repo.SaveMany(ctx, rows, now)
}

// PurgeUser deletes every category of the user.
func (s *CategoryService) PurgeUser(ctx context.Context, userID uuid.UUID) error {
	return s.repo.DeleteByUser(ctx, userID)
}
