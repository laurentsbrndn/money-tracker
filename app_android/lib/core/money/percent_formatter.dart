/// Basis points with one decimal and a decimal comma: `1941` → `19,4%`,
/// `-250` → `-2,5%` (BUSINESS_RULES §4.5: one decimal only in the UI).
String formatBasisPoints(int bp) {
  final sign = bp < 0 ? '-' : '';
  final tenths = (bp.abs() + 5) ~/ 10;
  return '$sign${tenths ~/ 10},${tenths % 10}%';
}

/// A whole percent: `50` → `50%`.
String formatPercent(int percent) => '$percent%';
