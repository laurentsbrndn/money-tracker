import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/reconcile_view.dart';

/// The "Selisih" card of the dashboard (APP_FLOWS Flow 2 step 4): green when
/// everything matches, yellow with a "Cocokkan" button when an account
/// differs, grey "Update saldo aktual" when an account is stale.
class DifferenceCard extends StatelessWidget {
  const DifferenceCard({
    required this.view,
    required this.hideAmounts,
    required this.onReconcile,
    super.key,
  });

  final ReconcileView view;
  final bool hideAmounts;
  final VoidCallback onReconcile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final Color color;
    final IconData icon;
    final String title;
    final String body;
    final bool showAction;
    if (view.mismatchCount > 0) {
      color = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      title = l10n.reconcileDiff(
        formatSignedRupiah(view.totals.diffTotal, hidden: hideAmounts),
      );
      body = l10n.diffMismatchBody(view.mismatchCount);
      showAction = true;
    } else if (view.staleCount > 0) {
      color = theme.colorScheme.outline;
      icon = Icons.update;
      title = l10n.diffStaleTitle;
      body = l10n.diffStaleBody(view.staleCount);
      showAction = true;
    } else {
      color = AppColors.income;
      icon = Icons.check_circle_outline;
      title = l10n.diffMatchedTitle;
      body = l10n.diffMatchedBody;
      showAction = false;
    }

    return Card(
      color: color.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            if (showAction)
              FilledButton.tonal(
                onPressed: onReconcile,
                child: Text(l10n.diffAction),
              ),
          ],
        ),
      ),
    );
  }
}
