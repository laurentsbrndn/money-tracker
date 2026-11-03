import 'package:flutter/material.dart';

import '../../../../core/security/pin_hasher.dart';

/// Six dots and a number pad. It reports every change of the typed digits and
/// calls [onComplete] once all [pinLength] digits are in; the caller decides
/// what happens next and clears the pad by changing [resetKey].
class PinPad extends StatefulWidget {
  const PinPad({
    required this.onComplete,
    this.enabled = true,
    this.biometricButton,
    super.key,
  });

  final ValueChanged<String> onComplete;

  /// False while a check runs or the pad is locked out.
  final bool enabled;

  /// Shown in the empty slot left of the zero key (fingerprint button).
  final Widget? biometricButton;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _digits = '';

  /// Empties the dots (after a wrong or mismatched PIN).
  void clear() => setState(() => _digits = '');

  void _press(String digit) {
    if (!widget.enabled || _digits.length >= pinLength) {
      return;
    }
    setState(() => _digits += digit);
    if (_digits.length == pinLength) {
      widget.onComplete(_digits);
    }
  }

  void _backspace() {
    if (!widget.enabled || _digits.isEmpty) {
      return;
    }
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < pinLength; i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _digits.length
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(color: theme.colorScheme.outline),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _row([for (final digit in row) _key(digit)]),
        _row([
          widget.biometricButton ?? const SizedBox.shrink(),
          _key('0'),
          IconButton(
            iconSize: 28,
            onPressed: widget.enabled ? _backspace : null,
            icon: const Icon(Icons.backspace_outlined),
          ),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final child in children)
          SizedBox(width: 88, height: 64, child: Center(child: child)),
      ],
    ),
  );

  Widget _key(String digit) => TextButton(
    onPressed: widget.enabled ? () => _press(digit) : null,
    style: TextButton.styleFrom(
      shape: const CircleBorder(),
      minimumSize: const Size(64, 64),
    ),
    child: Text(digit, style: Theme.of(context).textTheme.headlineSmall),
  );
}
