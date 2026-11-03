import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../reconciliation/application/reconciliation_providers.dart';
import '../../../reconciliation/domain/reconcile_item.dart';
import '../../../reconciliation/presentation/widgets/actual_money_card.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../application/accounts_providers.dart';
import '../../domain/account_type_labels.dart';
import '../../domain/account_with_balance.dart';
import '../widgets/account_tile.dart';

/// Accounts tab (APP_FLOWS Flow 5): the real money, the expected total, and
/// the accounts by type with their reconciliation badge.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(accountsOverviewProvider);
    final hide = ref.watch(hideAmountsProvider);
    final view = ref.watch(reconcileViewProvider).value;
    final reconcileById = {
      for (final entry in view?.items ?? const <ReconcileItem>[])
        entry.account.id: entry,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabAccounts),
        actions: [
          IconButton(
            tooltip: l10n.accountsReconcileAction,
            onPressed: () => context.push(RoutePaths.reconcile),
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.accountsAdd,
        onPressed: () => context.push(RoutePaths.accountNew),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
        child: AsyncBody(
          value: overview,
          onRetry: () => ref.invalidate(accountsOverviewProvider),
          builder: (data) {
            if (data.items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: l10n.accountsEmptyTitle,
                      message: l10n.accountsEmptyBody,
                    ),
                  ),
                ],
              );
            }
            final active = [
              for (final item in data.items)
                if (item.account.archivedAt == null) item,
            ];
            final archived = [
              for (final item in data.items)
                if (item.account.archivedAt != null) item,
            ];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                if (view != null && view.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: ActualMoneyCard(view: view, hideAmounts: hide),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountsTotal,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          AmountText(
                            data.expectedTotal,
                            hidden: hide,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final type in accountTypeValues)
                  ..._section(context, accountTypeLabel(l10n, type), [
                    for (final item in active)
                      if (item.account.type == type) item,
                  ], hide, reconcileById),
                ..._section(
                  context,
                  l10n.accountsArchivedSection,
                  archived,
                  hide,
                  reconcileById,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<AccountWithBalance> items,
    bool hide,
    Map<String, ReconcileItem> reconcileById,
  ) {
    if (items.isEmpty) {
      return const [];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge),
      ),
      for (final item in items)
        AccountTile(
          item: item,
          hideAmounts: hide,
          reconcile: reconcileById[item.account.id],
          onTap: () => context.push(RoutePaths.account(item.account.id)),
        ),
    ];
  }
}
