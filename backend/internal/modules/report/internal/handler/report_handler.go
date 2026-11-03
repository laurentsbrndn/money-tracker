// Package handler serves the report endpoints.
package handler

import (
	"errors"
	"strconv"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/domainrules"
	"moneytracker/internal/modules/report/internal/dto"
	"moneytracker/internal/modules/report/internal/service"
	"moneytracker/internal/platform/httpx"
)

// ReportHandler serves /v1/reports/*.
type ReportHandler struct {
	monthly *service.MonthlyReportService
	trend   *service.TrendService
}

// NewReportHandler builds the handler.
func NewReportHandler(monthly *service.MonthlyReportService, trend *service.TrendService) *ReportHandler {
	return &ReportHandler{monthly: monthly, trend: trend}
}

// Monthly handles GET /v1/reports/monthly?month=YYYY-MM.
func (h *ReportHandler) Monthly(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	month, err := domainrules.ParseYearMonth(c.Query("month"))
	if err != nil {
		return httpx.Validation("Parameter tidak valid", httpx.FieldError{Field: "month", Message: "harus berformat YYYY-MM"})
	}
	report, err := h.monthly.Monthly(c.Context(), userID, month)
	if err != nil {
		if errors.Is(err, service.ErrHistoryLimit) {
			return httpx.New(403, httpx.CodeHistoryLimit, "Bulan ini di luar batas riwayat paket gratis")
		}
		return httpx.Internal(err)
	}
	return httpx.OK(c, dto.NewMonthlyReport(report))
}

// Trend handles GET /v1/reports/trend?months=6|12 (premium).
func (h *ReportHandler) Trend(c fiber.Ctx) error {
	userID, ok := httpx.UserID(c)
	if !ok {
		return httpx.Unauthorized("Token tidak ada")
	}
	months := 6
	if raw := c.Query("months"); raw != "" {
		n, err := strconv.Atoi(raw)
		if err != nil || (n != 6 && n != 12) {
			return httpx.Validation("Parameter tidak valid", httpx.FieldError{Field: "months", Message: "harus 6 atau 12"})
		}
		months = n
	}
	trend, err := h.trend.Trend(c.Context(), userID, months)
	if err != nil {
		if errors.Is(err, service.ErrPremiumRequired) {
			return httpx.New(403, httpx.CodePremiumRequired, "Laporan tren hanya untuk paket premium")
		}
		return httpx.Internal(err)
	}
	return httpx.OK(c, dto.NewTrend(trend))
}
