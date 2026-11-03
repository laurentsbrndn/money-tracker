import 'package:flutter/material.dart';

import '../../../../core/domain_rules/budget.dart';
import '../../../../core/domain_rules/types.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/money/percent_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'allocation_labels.dart';

/// One bucket of the budget: goal against actual (APP_FLOWS Flow 2 step 5 and
/// Flow 6 step 2). With [compact] only the bar and the two amounts show.
class BudgetAllocationRow extends StatelessWidget {
  const BudgetAllocationRow({
    required this.allocation,
    required this.goalPct,
    required this.result,
    required this.hideAmounts,
    this.compact = false,
    this.onTap,
    super.key,
  });

  final Allocation allocation;
  final int goalPct;
  final AllocationResult result;
  final bool hideAmounts;
  final bool compact;
  final VoidCallback? onTap;

  bool get _over => result.goalAmount > 0 && result.actual > result.goalAmount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final spendBucket = allocation != Allocation.savings;
    final Color barColor;
    if (_over && spendBucket) {
      // Wants over its goal is red (APP_FLOWS Flow 2); needs is a softer warning.
      barColor = allocation == Allocation.wants
          ? AppColors.expense
          : AppColors.warning;
    } else if (allocation == Allocation.savings &&
        result.goalAmount > 0 &&
        result.actual >= result.goalAmount) {
      barColor = AppColors.income;
    } else {
      barColor = theme.colorScheme.primary;
    }
    final ratio = result.goalAmount > 0
        ? (result.actual / result.goalAmount).clamp(0.0, 1.0)
        : (result.actual > 0 ? 1.0 : 0.0);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                allocationName(l10n, allocation),
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              AmountText(
                result.actual,
                hidden: hideAmounts,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: _over && spendBucket ? barColor : null,
                ),
              ),
              if (compact) ...[
                Text(' / ', style: theme.textTheme.bodySmall),
                AmountText(
                  result.goalAmount,
                  hidden: hideAmounts,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: barColor,
            borderRadius: BorderRadius.circular(4),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              l10n.budgetGoalLine(
                goalPct,
                formatRupiah(result.goalAmount, hidden: hideAmounts),
              ),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              l10n.budgetActualLine(
                result.actualBp == null
                    ? '–'
                    : formatBasisPoints(result.actualBp!),
                formatRupiah(result.actual, hidden: hideAmounts),
              ),
              style: theme.textTheme.bodySmall,
            ),
            Text(
              _remainingText(l10n),
              style: theme.textTheme.bodySmall?.copyWith(
                color: _over && spendBucket ? barColor : null,
              ),
            ),
          ],
        ],
      ),
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }

  String _remainingText(AppLocalizations l10n) {
    final amount = formatRupiah(result.remaining.abs(), hidden: hideAmounts);
    if (allocation == Allocation.savings) {
      // Remaining savings is what is still missing from the goal.
      if (result.remaining > 0) {
        return l10n.budgetShort(amount);
      }
      return result.remaining < 0
          ? l10n.budgetOver(amount)
          : l10n.budgetRemaining(amount);
    }
    return result.remaining >= 0
        ? l10n.budgetRemaining(amount)
        : l10n.budgetOver(amount);
  }
}
