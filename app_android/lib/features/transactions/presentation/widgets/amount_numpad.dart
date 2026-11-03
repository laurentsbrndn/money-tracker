import 'package:flutter/material.dart';

/// Large numeric keypad of the entry form (FRONTEND_FLUTTER §4.6). Emits
/// digits (including `000`) and backspace; the form owns the value.
class AmountNumpad extends StatelessWidget {
  const AmountNumpad({
    required this.onDigits,
    required this.onBackspace,
    this.onClear,
    super.key,
  });

  final ValueChanged<String> onDigits;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '⌫'],
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Row(
            children: [
              for (final key in row)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextButton(
                      onPressed: key == '⌫' ? onBackspace : () => onDigits(key),
                      onLongPress: key == '⌫' ? onClear : null,
                      child: key == '⌫'
                          ? const Icon(Icons.backspace_outlined)
                          : Text(
                              key,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
