import 'package:flutter/material.dart';

import '../money/money_formatter.dart';
import '../theme/app_colors.dart';

enum AmountKind { income, expense, transfer, neutral }

/// A rupiah amount coloured by kind (FRONTEND_FLUTTER §4.6); with
/// [hidden] it shows `Rp •••••`.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount, {
    this.kind = AmountKind.neutral,
    this.hidden = false,
    this.style,
    this.signed = false,
    super.key,
  });

  final int amount;
  final AmountKind kind;
  final bool hidden;
  final TextStyle? style;

  /// Prefix `+` / `-` according to [kind].
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) {
      AmountKind.income => AppColors.income,
      AmountKind.expense => AppColors.expense,
      AmountKind.transfer => AppColors.transfer,
      AmountKind.neutral => amount < 0 ? AppColors.expense : null,
    };
    final prefix = !signed
        ? ''
        : switch (kind) {
            AmountKind.income => '+',
            AmountKind.expense => '-',
            _ => '',
          };
    return Text(
      '$prefix${formatRupiah(amount, hidden: hidden)}',
      style: (style ?? const TextStyle()).copyWith(color: color),
    );
  }
}
