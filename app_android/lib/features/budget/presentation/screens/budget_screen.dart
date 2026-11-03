import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain_rules/types.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../dashboard/application/dashboard_providers.dart';
import '../../../dashboard/presentation/widgets/month_selector.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../application/budget_providers.dart';
import '../../domain/budget_evaluation.dart';
import '../widgets/budget_allocation_row.dart';
import '../widgets/budget_breakdown_sheet.dart';
import '../widgets/budget_evaluation_card.dart';

/// Budget tab (APP_FLOWS Flow 6): goal against actual per bucket, what is not
/// yet allocated, and the per-category breakdown behind each bucket.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(selectedMonthProvider);
    final budget = ref.watch(monthBudgetProvider(month));
    final hide = ref.watch(hideAmountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const MonthSelector(),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: l10n.budgetSetGoal,
            onPressed: () => context.push(RoutePaths.budgetGoal),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
        child: AsyncBody(
          value: budget,
          onRetry: () => ref.invalidate(monthBudgetProvider(month)),
          builder: (data) {
            if (data.goal == null) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      icon: Icons.pie_chart_outline,
                      title: l10n.budgetNoGoalTitle,
                      message: l10n.budgetNoGoalBody,
                      action: FilledButton(
                        onPressed: () => context.push(RoutePaths.budgetGoal),
                        child: Text(l10n.budgetSetGoal),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (showsEvaluation(data)) BudgetEvaluationCard(month: data),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.budgetBasis(
                            formatRupiah(data.budget.basis, hidden: hide),
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          l10n.budgetBasisHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        for (final allocation in Allocation.values)
                          BudgetAllocationRow(
                            allocation: allocation,
                            goalPct: data.pctOf(allocation),
                            result: data.resultOf(allocation),
                            hideAmounts: hide,
                            onTap: () => unawaited(
                              showBudgetBreakdownSheet(
                                context,
                                month: month,
                                allocation: allocation,
                              ),
                            ),
                          ),
                        const Divider(),
                        Row(
                          children: [
                            Text(l10n.budgetUnallocated),
                            const Spacer(),
                            AmountText(
                              data.budget.unallocated,
                              hidden: hide,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
