import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/sync_badge.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../budget/application/budget_providers.dart';
import '../../../reconciliation/application/reconciliation_providers.dart';
import '../../../reconciliation/presentation/widgets/actual_money_card.dart';
import '../../../reconciliation/presentation/widgets/difference_card.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../application/dashboard_providers.dart';
import '../widgets/budget_card.dart';
import '../widgets/month_selector.dart';
import '../widgets/summary_card.dart';
import '../widgets/verify_email_banner.dart';

/// Dashboard (APP_FLOWS Flow 2): month summary, real money, difference,
/// budget, and the latest transactions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider(month));
    final recent = ref.watch(recentTransactionsProvider);
    final hide = ref.watch(hideAmountsProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final reconcileView = ref.watch(reconcileViewProvider).value;
    final budget = ref.watch(monthBudgetProvider(month)).value;
    final empty = recent.hasValue && !ref.watch(hasAnyTransactionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const MonthSelector(),
        centerTitle: false,
        actions: const [SyncBadge(), SizedBox(width: 12)],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addTransactionTooltip,
        onPressed: () => context.push(RoutePaths.transactionNew),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const VerifyEmailBanner(),
            summary.when(
              data: (value) => SummaryCard(summary: value, hideAmounts: hide),
              loading: () => const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => Text(l10n.errorGeneric),
            ),
            if (reconcileView != null && reconcileView.items.isNotEmpty) ...[
              ActualMoneyCard(
                view: reconcileView,
                hideAmounts: hide,
                onTap: () => context.go(RoutePaths.accounts),
              ),
              DifferenceCard(
                view: reconcileView,
                hideAmounts: hide,
                onReconcile: () => context.push(RoutePaths.reconcile),
              ),
            ],
            if (budget != null)
              BudgetCard(
                month: budget,
                hideAmounts: hide,
                onTap: () => context.go(RoutePaths.budget),
              ),
            const SizedBox(height: 16),
            if (empty)
              SizedBox(
                height: 320,
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.dashboardEmptyTitle,
                  message: l10n.dashboardEmptyBody,
                  action: FilledButton(
                    onPressed: () => context.push(RoutePaths.transactionNew),
                    child: Text(l10n.dashboardAddFirst),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    l10n.dashboardRecent,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(RoutePaths.transactions),
                    child: Text(l10n.dashboardSeeAll),
                  ),
                ],
              ),
              for (final transaction
                  in recent.value ?? const <TransactionRow>[])
                TransactionTile(
                  transaction: transaction,
                  categories: categories,
                  accounts: accounts,
                  hideAmounts: hide,
                  onTap: () =>
                      context.push(RoutePaths.transaction(transaction.id)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
