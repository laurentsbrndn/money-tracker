package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"

	"moneytracker/internal/modules/ledger/internal/model"
	"moneytracker/internal/platform/civil"
)

// FlowRow is the sum of the counted transactions that share a day, type, account pair and
// allocation.
type FlowRow struct {
	Type            string
	TransactionDate civil.Date
	AccountID       uuid.UUID
	ToAccountID     *uuid.UUID
	Allocation      *string
	Amount          int64
}

// CategoryTotalRow is the sum of one category's counted transactions.
type CategoryTotalRow struct {
	CategoryID *uuid.UUID
	Amount     int64
}

// countedWhere limits a query to the transactions that take part in the formulas
// (docs/BUSINESS_RULES.md §3): live, posted, and dated on or before asOf.
const countedWhere = "user_id = ? AND deleted_at IS NULL AND status = ? AND transaction_date <= ?"

// Flows sums the counted transactions of the user per day, type, account pair and allocation.
func (r *TransactionRepository) Flows(ctx context.Context, userID uuid.UUID, asOf civil.Date) ([]FlowRow, error) {
	var rows []FlowRow
	err := r.DB(ctx).Model(&model.Transaction{}).
		Select("type, transaction_date, account_id, to_account_id, allocation, COALESCE(SUM(amount), 0) AS amount").
		Where(countedWhere, userID, model.StatusPosted, asOf).
		Group("type, transaction_date, account_id, to_account_id, allocation").
		Order("transaction_date, type, account_id").
		Scan(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("sum transaction flows: %w", err)
	}
	return rows, nil
}

// CategoryTotals sums the counted transactions of one type per category within [from, to],
// largest first (ties by category id so the order is stable).
func (r *TransactionRepository) CategoryTotals(ctx context.Context, userID uuid.UUID, txType string, from, to civil.Date) ([]CategoryTotalRow, error) {
	var rows []CategoryTotalRow
	err := r.DB(ctx).Model(&model.Transaction{}).
		Select("category_id, COALESCE(SUM(amount), 0) AS amount").
		Where(countedWhere+" AND type = ? AND transaction_date >= ?", userID, model.StatusPosted, to, txType, from).
		Group("category_id").
		Order("amount DESC, category_id").
		Scan(&rows).Error
	if err != nil {
		return nil, fmt.Errorf("sum %s by category: %w", txType, err)
	}
	return rows, nil
}
