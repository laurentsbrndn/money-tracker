import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/money_formatter.dart';
import '../money/money_input_formatter.dart';

/// Text field for a rupiah amount: digits only, grouped as you type. Read the
/// value with [MoneyField.valueOf].
class MoneyField extends StatelessWidget {
  const MoneyField({
    required this.controller,
    required this.label,
    this.allowNegative = false,
    this.validator,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;

  /// A leading minus is kept (opening balances may be negative).
  final bool allowNegative;
  final String? Function(String?)? validator;
  final bool autofocus;
  final ValueChanged<int?>? onChanged;

  /// The amount in [controller], or null while empty.
  static int? valueOf(
    TextEditingController controller, {
    bool negative = false,
  }) {
    final digits = parseRupiahDigits(controller.text);
    if (digits == null) {
      return null;
    }
    return negative && controller.text.trimLeft().startsWith('-')
        ? -digits
        : digits;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(signed: allowNegative),
      inputFormatters: [
        if (allowNegative)
          _SignedMoneyFormatter()
        else ...[
          FilteringTextInputFormatter.digitsOnly,
          const MoneyInputFormatter(),
        ],
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'Rp ',
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      onChanged: (_) => onChanged?.call(
        MoneyField.valueOf(controller, negative: allowNegative),
      ),
    );
  }
}

/// Like [MoneyInputFormatter] but keeps a leading `-`.
class _SignedMoneyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final negative = newValue.text.trimLeft().startsWith('-');
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return negative
          ? const TextEditingValue(
              text: '-',
              selection: TextSelection.collapsed(offset: 1),
            )
          : const TextEditingValue();
    }
    final limited = digits.length > 12 ? digits.substring(0, 12) : digits;
    final text = '${negative ? '-' : ''}${groupThousands(int.parse(limited))}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
