package domainrules

// RoundHalfUp returns p / q rounded to the nearest integer, halves away from zero
// (docs/BUSINESS_RULES.md §4.5). q must be positive.
//
// For p >= 0 it is (p*2 + q) / (q*2) with integer division; for p < 0 it is the negated
// result for -p. Callers keep p small enough that p*2 does not overflow int64
// (amounts are capped at 999.999.999.999 and multiplied by at most 10000).
func RoundHalfUp(p, q int64) int64 {
	if p < 0 {
		return -RoundHalfUp(-p, q)
	}
	return (p*2 + q) / (q * 2)
}
