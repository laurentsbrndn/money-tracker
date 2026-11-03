package syncbase

import (
	"strings"
	"time"
	"unicode/utf8"

	"moneytracker/internal/platform/civil"
)

// MaxAmount is the largest absolute amount accepted anywhere (docs/BUSINESS_RULES.md §6).
// The rounding rules rely on it to stay inside int64.
const MaxAmount int64 = 999_999_999_999

// AmountInRange reports whether |v| <= MaxAmount.
func AmountInRange(v int64) bool {
	return v >= -MaxAmount && v <= MaxAmount
}

// TextLen reports whether s has between min and max characters (runes). When min is at least
// 1 the text must also contain something other than white space.
func TextLen(s string, min, max int) bool {
	n := utf8.RuneCountInString(s)
	if n < min || n > max {
		return false
	}
	return min < 1 || strings.TrimSpace(s) != ""
}

// LatestDate returns the last calendar date accepted for "not after today" rules: today in UTC
// plus slackDays. The modules cannot read the user's timezone, so a day of slack keeps users
// ahead of UTC (for example in WIB) from being rejected (docs/BUSINESS_RULES.md §6).
func LatestDate(now time.Time, slackDays int) civil.Date {
	return civil.FromTime(now.UTC()).AddDays(slackDays)
}
