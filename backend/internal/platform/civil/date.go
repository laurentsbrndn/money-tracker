package civil

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

const layout = "2006-01-02"

// Date is a calendar date (YYYY-MM-DD) without time of day or time zone.
// The zero value is the zero date and reports IsZero.
type Date struct {
	year  int
	month time.Month
	day   int
}

// New builds a Date, normalizing out-of-range month or day values like time.Date does.
func New(year int, month time.Month, day int) Date {
	return FromTime(time.Date(year, month, day, 0, 0, 0, 0, time.UTC))
}

// FromTime returns the calendar date of t in t's own location.
func FromTime(t time.Time) Date {
	y, m, d := t.Date()
	return Date{year: y, month: m, day: d}
}

// Parse reads a strict YYYY-MM-DD string.
func Parse(s string) (Date, error) {
	t, err := time.Parse(layout, s)
	if err != nil {
		return Date{}, fmt.Errorf("parse date %q: %w", s, err)
	}
	return FromTime(t), nil
}

// Today returns the calendar date of now in loc.
func Today(now time.Time, loc *time.Location) Date {
	return FromTime(now.In(loc))
}

// IsZero reports whether d is the zero date.
func (d Date) IsZero() bool {
	return d.year == 0 && d.month == 0 && d.day == 0
}

// Year returns the year.
func (d Date) Year() int { return d.year }

// Month returns the month.
func (d Date) Month() time.Month { return d.month }

// Day returns the day of the month.
func (d Date) Day() int { return d.day }

// Weekday returns the day of the week.
func (d Date) Weekday() time.Weekday { return d.utc().Weekday() }

// ISOWeekday returns the ISO weekday: Monday = 1 ... Sunday = 7.
func (d Date) ISOWeekday() int {
	w := int(d.Weekday())
	if w == 0 {
		return 7
	}
	return w
}

// String formats the date as YYYY-MM-DD.
func (d Date) String() string {
	return d.utc().Format(layout)
}

// AddDays returns d shifted by n days (n may be negative).
func (d Date) AddDays(n int) Date {
	return FromTime(d.utc().AddDate(0, 0, n))
}

// DaysSince returns the number of days from o to d (negative when d is earlier).
func (d Date) DaysSince(o Date) int {
	return int(d.utc().Sub(o.utc()).Hours() / 24)
}

// Compare returns -1, 0, or 1 when d is before, equal to, or after o.
func (d Date) Compare(o Date) int {
	switch {
	case d.year != o.year:
		return sign(d.year - o.year)
	case d.month != o.month:
		return sign(int(d.month) - int(o.month))
	default:
		return sign(d.day - o.day)
	}
}

// Before reports whether d is earlier than o.
func (d Date) Before(o Date) bool { return d.Compare(o) < 0 }

// After reports whether d is later than o.
func (d Date) After(o Date) bool { return d.Compare(o) > 0 }

// Equal reports whether d and o are the same date.
func (d Date) Equal(o Date) bool { return d.Compare(o) == 0 }

// FirstOfMonth returns the first day of d's month.
func (d Date) FirstOfMonth() Date {
	return Date{year: d.year, month: d.month, day: 1}
}

// LastOfMonth returns the last day of d's month.
func (d Date) LastOfMonth() Date {
	return Date{year: d.year, month: d.month, day: DaysInMonth(d.year, d.month)}
}

// DaysInMonth returns the number of days in the given month.
func DaysInMonth(year int, month time.Month) int {
	return time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC).Day()
}

// MarshalJSON encodes the date as "YYYY-MM-DD".
func (d Date) MarshalJSON() ([]byte, error) {
	return json.Marshal(d.String())
}

// UnmarshalJSON decodes a strict "YYYY-MM-DD" string.
func (d *Date) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return fmt.Errorf("decode date: %w", err)
	}
	parsed, err := Parse(s)
	if err != nil {
		return err
	}
	*d = parsed
	return nil
}

// Value implements driver.Valuer; the date is stored as a SQL date.
func (d Date) Value() (driver.Value, error) {
	if d.IsZero() {
		return nil, nil
	}
	return d.String(), nil
}

// Scan implements sql.Scanner for date columns.
func (d *Date) Scan(src any) error {
	switch v := src.(type) {
	case nil:
		*d = Date{}
	case time.Time:
		*d = New(v.Year(), v.Month(), v.Day())
	case string:
		parsed, err := Parse(v)
		if err != nil {
			return err
		}
		*d = parsed
	case []byte:
		parsed, err := Parse(string(v))
		if err != nil {
			return err
		}
		*d = parsed
	default:
		return fmt.Errorf("scan date: unsupported type %T", src)
	}
	return nil
}

func (d Date) utc() time.Time {
	return time.Date(d.year, d.month, d.day, 0, 0, 0, 0, time.UTC)
}

func sign(n int) int {
	switch {
	case n < 0:
		return -1
	case n > 0:
		return 1
	default:
		return 0
	}
}
