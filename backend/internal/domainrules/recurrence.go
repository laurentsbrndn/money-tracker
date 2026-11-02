package domainrules

import (
	"time"

	"moneytracker/internal/platform/civil"
)

// RecurringFrequency is recurring_rules.frequency.
type RecurringFrequency string

const (
	FrequencyDaily   RecurringFrequency = "daily"
	FrequencyWeekly  RecurringFrequency = "weekly"
	FrequencyMonthly RecurringFrequency = "monthly"
	FrequencyYearly  RecurringFrequency = "yearly"
)

// maxOccurrenceSteps bounds the search so a malformed rule can never loop for long.
const maxOccurrenceSteps = 200_000

// RecurrenceRule holds the schedule fields of a recurring rule.
//
// DayOfWeek is ISO (Monday = 1 ... Sunday = 7) and does not follow user_settings.week_start,
// so occurrence IDs are identical on every device. EndDate is the zero date when open-ended.
type RecurrenceRule struct {
	Frequency     RecurringFrequency
	IntervalCount int
	DayOfWeek     int // weekly
	DayOfMonth    int // monthly, yearly
	MonthOfYear   int // yearly
	StartDate     civil.Date
	EndDate       civil.Date
}

// Occurrences returns, in ascending order, the dates that are due: later than lastGenerated
// (or on/after StartDate when lastGenerated is the zero date) and on/before today, never
// before StartDate nor after EndDate (docs/BUSINESS_RULES.md §5.1–§5.2).
//
// A rule whose required fields are missing or out of range yields no occurrences.
func Occurrences(rule RecurrenceRule, lastGenerated, today civil.Date) []civil.Date {
	if rule.IntervalCount < 1 || rule.StartDate.IsZero() {
		return nil
	}
	upper := today
	if !rule.EndDate.IsZero() && rule.EndDate.Before(upper) {
		upper = rule.EndDate
	}

	var due []civil.Date
	for n := range maxOccurrenceSteps {
		date, ok := nthOccurrence(rule, n)
		if !ok {
			return nil
		}
		if date.After(upper) {
			// Dates grow with n, but the first dates of weekly/monthly/yearly rules can precede
			// StartDate; only stop once past the upper bound.
			break
		}
		if date.Before(rule.StartDate) {
			continue
		}
		if !lastGenerated.IsZero() && !date.After(lastGenerated) {
			continue
		}
		due = append(due, date)
	}
	return due
}

// nthOccurrence returns the n-th candidate date of the rule (n starts at 0). Candidates can
// fall before StartDate (the first week, month, or year); callers skip those.
func nthOccurrence(rule RecurrenceRule, n int) (civil.Date, bool) {
	step := n * rule.IntervalCount
	start := rule.StartDate

	switch rule.Frequency {
	case FrequencyDaily:
		return start.AddDays(step), true

	case FrequencyWeekly:
		if rule.DayOfWeek < 1 || rule.DayOfWeek > 7 {
			return civil.Date{}, false
		}
		// The first week is the ISO (Monday-based) week that contains StartDate.
		weekStart := start.AddDays(-(start.ISOWeekday() - 1))
		return weekStart.AddDays(step*7 + rule.DayOfWeek - 1), true

	case FrequencyMonthly:
		if rule.DayOfMonth < 1 || rule.DayOfMonth > 31 {
			return civil.Date{}, false
		}
		return clampedDate(MonthOf(start).AddMonths(step), rule.DayOfMonth), true

	case FrequencyYearly:
		if rule.DayOfMonth < 1 || rule.DayOfMonth > 31 || rule.MonthOfYear < 1 || rule.MonthOfYear > 12 {
			return civil.Date{}, false
		}
		month := YearMonth{Year: start.Year() + step, Month: time.Month(rule.MonthOfYear)}
		return clampedDate(month, rule.DayOfMonth), true
	}
	return civil.Date{}, false
}

// clampedDate returns the given day of month, or the month's last day when it is shorter
// (31 -> 30 Nov, 29 Feb -> 28 Feb in a non-leap year).
func clampedDate(month YearMonth, day int) civil.Date {
	return civil.New(month.Year, month.Month, min(day, civil.DaysInMonth(month.Year, month.Month)))
}
