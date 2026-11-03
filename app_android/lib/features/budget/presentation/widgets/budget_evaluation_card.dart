import 'package:flutter/material.dart';

import '../../../../core/domain_rules/types.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/budget_evaluation.dart';
import '../../domain/month_budget.dart';
import 'allocation_labels.dart';

/// Month-end evaluation (APP_FLOWS Flow 6 step 3).
class BudgetEvaluationCard extends StatelessWidget {
  const BudgetEvaluationCard({required this.month, super.key});

  final MonthBudget month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines = evaluateMonth(month);
    final allUnknown = lines.every(
      (line) => line.outcome == EvaluationOutcome.unknown,
    );
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.budgetEvalTitle(formatYearMonth(month.month)),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (allUnknown)
              Text(l10n.budgetEvalUnknown)
            else
              for (final line in lines)
                if (line.outcome != EvaluationOutcome.unknown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          line.outcome == EvaluationOutcome.good
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 18,
                          color: line.outcome == EvaluationOutcome.good
                              ? AppColors.income
                              : AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_text(l10n, line))),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  String _text(AppLocalizations l10n, AllocationEvaluation line) {
    final name = allocationName(l10n, line.allocation);
    final good = line.outcome == EvaluationOutcome.good;
    if (line.allocation == Allocation.savings) {
      return good ? l10n.budgetEvalReached(name) : l10n.budgetEvalShort(name);
    }
    return good ? l10n.budgetEvalWithin(name) : l10n.budgetEvalOver(name);
  }
}
