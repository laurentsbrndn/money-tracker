/// Namespace of the pure business rules (BUSINESS_RULES.md), one extension per file.
enum DomainRules {
    /// `p / q` rounded to the nearest integer, halves away from zero (§4.5). `q` must be positive.
    ///
    /// For `p >= 0` it is `(p * 2 + q) / (q * 2)` with integer division; for `p < 0` it is the
    /// negated result for `-p`. Amounts are capped at 999.999.999.999 and multiplied by at most
    /// 10000, so `p * 2` stays inside `Int64`.
    static func roundHalfUp(_ p: Int64, _ q: Int64) -> Int64 {
        if p < 0 {
            return -roundHalfUp(-p, q)
        }
        return (p * 2 + q) / (q * 2)
    }
}
