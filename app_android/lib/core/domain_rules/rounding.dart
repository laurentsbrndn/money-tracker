/// `p / q` rounded to the nearest integer, halves away from zero
/// (BUSINESS_RULES §4.5). [q] must be positive.
///
/// For `p >= 0` it is `(p * 2 + q) ~/ (q * 2)`; for `p < 0` it is the negated
/// result for `-p`.
int roundHalfUp(int p, int q) {
  if (p < 0) {
    return -roundHalfUp(-p, q);
  }
  return (p * 2 + q) ~/ (q * 2);
}
