package domainrules

import (
	"fmt"
	"time"
	_ "time/tzdata" // embed the IANA database; the serverless runtime has no zoneinfo files

	"moneytracker/internal/platform/civil"
)

// YearMonth is a calendar month (YYYY-MM), the reporting period.
type YearMonth struct {
	Year  int
	Month time.Month
}

// ParseYearMonth reads a strict "YYYY-MM" string.
func ParseYearMonth(s string) (YearMonth, error) {
	t, err := time.Parse("2006-01", s)
	if err != nil {
		return YearMonth{}, fmt.Errorf("parse month %q: %w", s, err)
	}
	return YearMonth{Year: t.Year(), Month: t.Month()}, nil
}

// MonthOf returns the month that contains d.
func MonthOf(d civil.Date) YearMonth {
	return YearMonth{Year: d.Year(), Month: d.Month()}
}

// String formats the month as YYYY-MM.
func (m YearMonth) String() string {
	return fmt.Sprintf("%04d-%02d", m.Year, int(m.Month))
}

// First returns the first day of the month.
func (m YearMonth) First() civil.Date {
	return civil.New(m.Year, m.Month, 1)
}

// Last returns the last day of the month.
func (m YearMonth) Last() civil.Date {
	return m.First().LastOfMonth()
}

// Contains reports whether d falls inside the month.
func (m YearMonth) Contains(d civil.Date) bool {
	return d.Year() == m.Year && d.Month() == m.Month
}

// AddMonths returns the month n months after m (n may be negative).
func (m YearMonth) AddMonths(n int) YearMonth {
	index := m.Year*12 + int(m.Month) - 1 + n
	year := index / 12
	month := index % 12
	if month < 0 {
		month += 12
		year--
	}
	return YearMonth{Year: year, Month: time.Month(month + 1)}
}

// Compare returns -1, 0, or 1 when m is before, equal to, or after o.
func (m YearMonth) Compare(o YearMonth) int {
	switch {
	case m.Year != o.Year:
		if m.Year < o.Year {
			return -1
		}
		return 1
	case m.Month != o.Month:
		if m.Month < o.Month {
			return -1
		}
		return 1
	default:
		return 0
	}
}

// Today returns the calendar date "now" in the user's time zone (docs/BUSINESS_RULES.md §1).
func Today(now time.Time, timezone string) (civil.Date, error) {
	loc, err := time.LoadLocation(timezone)
	if err != nil {
		return civil.Date{}, fmt.Errorf("load timezone %q: %w", timezone, err)
	}
	return civil.Today(now, loc), nil
}
