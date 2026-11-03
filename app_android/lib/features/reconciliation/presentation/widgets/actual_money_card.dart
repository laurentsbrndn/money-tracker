import 'package:flutter/material.dart';

import '../../../../core/time/civil_date_format.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/reconcile_view.dart';

/// "Uang aktual" (APP_FLOWS Flow 2 step 3): the real balances the user last
/// observed, split into bank/e-wallet/savings and cash.
class ActualMoneyCard extends StatelessWidget {
  const ActualMoneyCard({
    required this.view,
    required this.hideAmounts,
    this.onTap,
    super.key,
  });

  final ReconcileView view;
  final bool hideAmounts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final totals = view.totals;
    final updated = view.lastUpdated;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.actualMoneyTitle, style: theme.textTheme.labelLarge),
              AmountText(
                totals.actualTotal,
                hidden: hideAmounts,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Figure(
                      label: l10n.actualMoneyAccounts,
                      amount: totals.actualAccounts,
                      hidden: hideAmounts,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      label: l10n.actualMoneyCash,
                      amount: totals.actualCash,
                      hidden: hideAmounts,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                updated == null
                    ? l10n.actualMoneyNone
                    : l10n.actualMoneyUpdated(formatCivilDateShort(updated)),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.hidden,
  });

  final String label;
  final int amount;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        AmountText(amount, hidden: hidden, style: theme.textTheme.titleMedium),
      ],
    );
  }
}
