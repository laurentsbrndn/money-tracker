import 'package:flutter/material.dart';

import '../../../../core/domain_rules/reconciliation.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/reconcile_item.dart';

/// The outcome for one account after its balance was entered: matched, or the
/// difference with the three choices of APP_FLOWS Flow 5 step 4.
class ReconcileResultTile extends StatelessWidget {
  const ReconcileResultTile({
    required this.item,
    required this.hideAmounts,
    required this.deferred,
    required this.adjustedAmount,
    required this.onMissed,
    required this.onAdjust,
    required this.onLater,
    required this.onReview,
    super.key,
  });

  final ReconcileItem item;
  final bool hideAmounts;

  /// The user chose "Nanti saja" for this account.
  final bool deferred;

  /// Signed adjustment booked in this visit, null if none.
  final int? adjustedAmount;
  final VoidCallback onMissed;
  final VoidCallback onAdjust;
  final VoidCallback onLater;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = item.result;
    final matched = result.status == ReconciliationStatus.matched;
    final account = item.account;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProviderLogo(providerKey: account.providerKey),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name, style: theme.textTheme.titleMedium),
                      Row(
                        children: [
                          Text(
                            '${l10n.reconcileActual} ',
                            style: theme.textTheme.bodySmall,
                          ),
                          AmountText(
                            result.latestSnapshotAmount,
                            hidden: hideAmounts,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (matched)
                  const Icon(Icons.check_circle, color: AppColors.income),
              ],
            ),
            if (matched) ...[
              const SizedBox(height: 8),
              Text(
                adjustedAmount == null
                    ? l10n.reconcileMatched
                    : '${l10n.reconcileMatched} · ${l10n.reconcileAdjusted(_signed(adjustedAmount!))}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.income,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    deferred ? '${l10n.reconcileDeferred} · ' : '',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    l10n.reconcileDiff(_signed(result.diff)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (deferred)
                TextButton(
                  onPressed: onReview,
                  child: Text(l10n.reconcileReview),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonal(
                      onPressed: onMissed,
                      child: Text(l10n.reconcileMissed),
                    ),
                    FilledButton.tonal(
                      onPressed: onAdjust,
                      child: Text(l10n.reconcileAdjust),
                    ),
                    TextButton(
                      onPressed: onLater,
                      child: Text(l10n.reconcileLater),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _signed(int value) => formatSignedRupiah(value, hidden: hideAmounts);
}
