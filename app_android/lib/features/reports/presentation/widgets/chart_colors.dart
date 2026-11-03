import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Chart colours that stay readable on both themes: the income and expense
/// colours of the app are lightened on dark backgrounds, and the neutral ones
/// come from the colour scheme.
class ChartColors {
  const ChartColors._(
    this.income,
    this.expense,
    this.neutral,
    this.accent,
    this.text,
    this.grid,
  );

  factory ChartColors.of(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    Color adapt(Color color) =>
        dark ? Color.lerp(color, Colors.white, 0.35)! : color;
    return ChartColors._(
      adapt(AppColors.income),
      adapt(AppColors.expense),
      theme.colorScheme.outline,
      theme.colorScheme.primary,
      theme.colorScheme.onSurfaceVariant,
      theme.colorScheme.outlineVariant,
    );
  }

  final Color income;
  final Color expense;

  /// Muted bars (the previous month of a comparison).
  final Color neutral;
  final Color accent;

  /// Axis labels.
  final Color text;
  final Color grid;
}
