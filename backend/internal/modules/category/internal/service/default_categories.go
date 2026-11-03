package service

import "moneytracker/internal/modules/category/internal/model"

// defaultCategory is one row of docs/BUSINESS_RULES.md §2.1. Colors are the shared palette of
// docs/DATA_MODEL.md §9; both apps read the color from the synced row.
type defaultCategory struct {
	Type       string
	Name       string
	Icon       string
	Color      string
	Allocation string // empty for income
}

// defaultCategories is in sort order within each type (sort_order = position within the type).
var defaultCategories = []defaultCategory{
	{model.TypeExpense, "Makan & Minum", "food", "#F59E0B", "needs"},
	{model.TypeExpense, "Transportasi", "transport", "#3B82F6", "needs"},
	{model.TypeExpense, "Tempat Tinggal", "home", "#8B5CF6", "needs"},
	{model.TypeExpense, "Tagihan & Utilitas", "bill", "#EF4444", "needs"},
	{model.TypeExpense, "Kesehatan", "health", "#10B981", "needs"},
	{model.TypeExpense, "Pendidikan", "education", "#06B6D4", "needs"},
	{model.TypeExpense, "Biaya Admin", "fee", "#6B7280", "needs"},
	{model.TypeExpense, "Belanja", "shopping", "#EC4899", "wants"},
	{model.TypeExpense, "Hiburan", "entertainment", "#F97316", "wants"},
	{model.TypeExpense, "Langganan", "subscription", "#6366F1", "wants"},
	{model.TypeExpense, "Jajan & Nongkrong", "snack", "#EAB308", "wants"},
	{model.TypeExpense, "Hadiah & Donasi", "gift", "#D946EF", "wants"},
	{model.TypeExpense, "Investasi", "investment", "#14B8A6", "savings"},
	{model.TypeExpense, "Lainnya", "other", "#9CA3AF", "wants"},
	{model.TypeIncome, "Gaji", "salary", "#22C55E", ""},
	{model.TypeIncome, "Freelance", "freelance", "#0EA5E9", ""},
	{model.TypeIncome, "Bonus", "bonus", "#84CC16", ""},
	{model.TypeIncome, "Hadiah", "gift", "#D946EF", ""},
	{model.TypeIncome, "Lainnya", "other", "#9CA3AF", ""},
}
