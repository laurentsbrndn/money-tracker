package dto

import "moneytracker/internal/modules/report/internal/service"

// TrendMonth is schema TrendMonth.
type TrendMonth struct {
	Month       string `json:"month"`
	Income      int64  `json:"income"`
	Expense     int64  `json:"expense"`
	Surplus     int64  `json:"surplus"`
	Savings     int64  `json:"savings"`
	Adjustments int64  `json:"adjustments"`
}

// NewTrend shapes the trend report for the wire: a JSON array, oldest month first.
func NewTrend(months []service.TrendMonth) []TrendMonth {
	out := make([]TrendMonth, 0, len(months))
	for _, m := range months {
		out = append(out, TrendMonth{
			Month: m.Month.String(), Income: m.Income, Expense: m.Expense, Surplus: m.Surplus,
			Savings: m.Savings, Adjustments: m.Adjustments,
		})
	}
	return out
}
