import 'package:flutter/services.dart';

import 'money_formatter.dart';

/// Keeps digits only and shows them grouped (`1.234.567`). Read the value back
/// with `parseRupiahDigits`.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.maxDigits = 12});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }
    if (digits.isEmpty) {
      return const TextEditingValue();
    }
    final text = groupThousands(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
