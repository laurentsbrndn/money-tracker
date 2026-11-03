/// Rupiah as whole numbers, Indonesian grouping: 25000 → `Rp 25.000`,
/// -1500 → `-Rp 1.500` (FRONTEND_FLUTTER §4.6).
String formatRupiah(int amount, {bool hidden = false}) {
  if (hidden) {
    return 'Rp •••••';
  }
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp ${groupThousands(amount.abs())}';
}

/// Like [formatRupiah] but with an explicit `+` for positive amounts, for
/// differences and adjustments: `+Rp 5.000`, `-Rp 5.000`.
String formatSignedRupiah(int amount, {bool hidden = false}) {
  if (hidden) {
    return 'Rp •••••';
  }
  return amount > 0 ? '+${formatRupiah(amount)}' : formatRupiah(amount);
}

/// `1234567` → `1.234.567` (no currency symbol).
String groupThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// The integer in `1.234.567` style text; null if it holds no digits.
int? parseRupiahDigits(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 15) {
    return null;
  }
  return int.parse(digits);
}
