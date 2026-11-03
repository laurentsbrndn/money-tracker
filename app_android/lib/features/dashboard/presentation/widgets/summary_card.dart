import 'package:flutter/material.dart';

import '../../../../core/domain_rules/balance.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// Income, expense and surplus of the selected month.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    required this.summary,
    required this.hideAmounts,
    super.key,
  });

  final MonthlySummary summary;
  final bool hideAmounts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.surplus >= 0
                  ? l10n.dashboardSurplus
                  : l10n.dashboardDeficit,
              style: theme.textTheme.labelLarge,
            ),
            AmountText(
              summary.surplus,
              hidden: hideAmounts,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: l10n.dashboardIncome,
                    amount: summary.income,
                    kind: AmountKind.income,
                    hidden: hideAmounts,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: l10n.dashboardExpense,
                    amount: summary.expense,
                    kind: AmountKind.expense,
                    hidden: hideAmounts,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.amount,
    required this.kind,
    required this.hidden,
  });

  final String label;
  final int amount;
  final AmountKind kind;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        AmountText(
          amount,
          kind: kind,
          hidden: hidden,
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}
