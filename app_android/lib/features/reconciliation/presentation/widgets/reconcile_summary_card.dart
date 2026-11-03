import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Step 5 of APP_FLOWS Flow 5: how many accounts match and how much was
/// adjusted.
class ReconcileSummaryCard extends StatelessWidget {
  const ReconcileSummaryCard({
    required this.matched,
    required this.total,
    required this.adjustedTotal,
    required this.hideAmounts,
    super.key,
  });

  final int matched;
  final int total;
  final int adjustedTotal;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reconcileSummaryTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.reconcileSummaryMatched(matched, total)),
            if (adjustedTotal != 0)
              Text(
                l10n.reconcileSummaryAdjusted(
                  formatSignedRupiah(adjustedTotal, hidden: hideAmounts),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
