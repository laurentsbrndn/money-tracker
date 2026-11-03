import 'package:flutter/material.dart';

import '../../../../core/domain_rules/types.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../budget/domain/month_budget.dart';
import '../../../budget/presentation/widgets/budget_allocation_row.dart';

/// Needs/wants/savings bars of the selected month (APP_FLOWS Flow 2 step 5):
/// goal against actual, and what is not allocated yet. Tap opens the Budget
/// tab.
class BudgetCard extends StatelessWidget {
  const BudgetCard({
    required this.month,
    required this.hideAmounts,
    required this.onTap,
    super.key,
  });

  final MonthBudget month;
  final bool hideAmounts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboardBudgetTitle,
                style: theme.textTheme.labelLarge,
              ),
              if (month.goal == null) ...[
                const SizedBox(height: 8),
                Text(l10n.budgetNoGoalTitle),
                Text(l10n.budgetNoGoalBody, style: theme.textTheme.bodySmall),
              ] else ...[
                for (final allocation in Allocation.values)
                  BudgetAllocationRow(
                    allocation: allocation,
                    goalPct: month.pctOf(allocation),
                    result: month.resultOf(allocation),
                    hideAmounts: hideAmounts,
                    compact: true,
                  ),
                const Divider(),
                Row(
                  children: [
                    Text(
                      l10n.budgetUnallocated,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    AmountText(
                      month.budget.unallocated,
                      hidden: hideAmounts,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
