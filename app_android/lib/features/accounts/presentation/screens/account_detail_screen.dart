import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/billing/plan_limits.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/validation/validation_exception.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/plan_limit_snack_bar.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../../transactions/application/transaction_lookups.dart';
import '../../../transactions/application/transactions_providers.dart';
import '../../../transactions/domain/transaction_filter.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../application/accounts_providers.dart';
import '../../domain/account_type_labels.dart';
import '../../domain/account_with_balance.dart';

/// Detail of one account: expected balance, its transactions, balance
/// snapshots, and edit/archive/delete (APP_FLOWS Flow 5).
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({required this.accountId, super.key});

  final String accountId;

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
    int balance,
  ) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (balance != 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.accountArchiveBalanceTitle),
          content: Text(
            l10n.accountArchiveBalanceBody(
              formatRupiah(balance, hidden: ref.read(hideAmountsProvider)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'archive'),
              child: Text(l10n.accountArchiveOnly),
            ),
            if (balance > 0)
              FilledButton(
                onPressed: () => Navigator.pop(context, 'transfer'),
                child: Text(l10n.accountArchiveTransfer),
              ),
          ],
        ),
      );
      if (choice == null) {
        return;
      }
      if (choice == 'transfer') {
        unawaited(
          router.push(
            Uri(
              path: RoutePaths.transactionNew,
              queryParameters: {
                'type': 'transfer',
                'from': account.id,
                'amount': '$balance',
              },
            ).toString(),
          ),
        );
        return;
      }
    }
    try {
      await ref
          .read(accountsRepositoryProvider)
          .setArchived(account, archived: true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountArchived)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  Future<void> _unarchive(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(accountsRepositoryProvider)
          .setArchived(account, archived: false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountUnarchived)));
    } on PlanLimitException {
      if (!context.mounted) {
        return;
      }
      showPlanLimitSnackBar(
        messenger,
        GoRouter.of(context),
        l10n,
        l10n.planLimitAccounts,
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AccountRow account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.accountDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(accountsRepositoryProvider).delete(account.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountDeleted)));
      router.pop();
    } on RecordInUseException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountInUse)));
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = ref.watch(accountByIdProvider(accountId)).value;
    final overview = ref.watch(accountsOverviewProvider).value;
    final hide = ref.watch(hideAmountsProvider);
    final transactions =
        ref.watch(accountTransactionsProvider(accountId)).value ??
        const <TransactionRow>[];
    final snapshots =
        ref.watch(accountSnapshotsProvider(accountId)).value ??
        const <BalanceSnapshotRow>[];
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);

    if (account == null || account.deletedAt != null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final balance = [
      for (final item in overview?.items ?? const <AccountWithBalance>[])
        if (item.account.id == accountId) item.expectedBalance,
    ].firstOrNull;
    final archived = account.archivedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  unawaited(context.push(RoutePaths.accountEdit(accountId)));
                case 'archive':
                  unawaited(_archive(context, ref, account, balance ?? 0));
                case 'unarchive':
                  unawaited(_unarchive(context, ref, account));
                case 'delete':
                  unawaited(_delete(context, ref, account));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'edit', child: Text(l10n.actionEdit)),
              PopupMenuItem(
                value: archived ? 'unarchive' : 'archive',
                child: Text(
                  archived ? l10n.accountUnarchive : l10n.accountArchive,
                ),
              ),
              PopupMenuItem(value: 'delete', child: Text(l10n.actionDelete)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ProviderLogo(providerKey: account.providerKey, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountTypeLabel(l10n, account.type),
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        l10n.accountDetailExpected,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (balance != null)
                        AmountText(
                          balance,
                          hidden: hide,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (archived)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.accountArchivedNotice),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  l10n.accountDetailTransactions,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref
                        .read(transactionListControllerProvider.notifier)
                        .setFilter(TransactionFilter(accountId: accountId));
                    context.go(RoutePaths.transactions);
                  },
                  child: Text(l10n.accountDetailSeeAll),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.accountDetailNoTransactions),
            )
          else
            for (final transaction in transactions.take(10))
              TransactionTile(
                transaction: transaction,
                categories: categories,
                accounts: accounts,
                hideAmounts: hide,
                onTap: transaction.type == 'adjustment'
                    ? null
                    : () =>
                          context.push(RoutePaths.transaction(transaction.id)),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              l10n.accountDetailSnapshots,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (snapshots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.accountDetailNoSnapshots),
            )
          else
            for (final snapshot in snapshots)
              ListTile(
                dense: true,
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(formatCivilDateShort(snapshot.snapshotDate)),
                subtitle: snapshot.note == null ? null : Text(snapshot.note!),
                trailing: AmountText(snapshot.amount, hidden: hide),
              ),
        ],
      ),
    );
  }
}
