import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/sync/sync_scheduler.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../recurring/presentation/widgets/pending_confirmation_section.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../application/transaction_lookups.dart';
import '../../application/transactions_providers.dart';
import '../../domain/day_group.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/transaction_tile.dart';

/// History of transactions (APP_FLOWS Flow 4): grouped by day, with filters,
/// search, swipe to delete (with undo), and long press for more.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      ref.read(transactionListControllerProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(transactionListControllerProvider.notifier).setQuery(text);
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _search.clear();
      ref.read(transactionListControllerProvider.notifier).setQuery('');
    }
  }

  Future<void> _openFilters() async {
    final controller = ref.read(transactionListControllerProvider.notifier);
    final current = ref.read(transactionListControllerProvider).filter;
    final result = await showTransactionFilterSheet(context, current);
    if (result != null) {
      controller.setFilter(result);
    }
  }

  Future<void> _delete(TransactionRow transaction) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(transactionsRepositoryProvider);
    final removed = await repository.delete(transaction.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.transactionDeleted),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.transactionUndo,
            onPressed: () => unawaited(repository.restore(removed)),
          ),
        ),
      );
  }

  Future<void> _longPress(TransactionRow transaction) async {
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (transaction.type != 'adjustment')
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: Text(l10n.transactionDuplicate),
                onTap: () => Navigator.pop(context, 'duplicate'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.actionDelete),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'duplicate':
        final copyId = await ref
            .read(transactionsRepositoryProvider)
            .duplicate(transaction.id);
        if (copyId != null) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.transactionDuplicated)),
          );
          unawaited(router.push(RoutePaths.transaction(copyId)));
        }
      case 'delete':
        await _delete(transaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(transactionListControllerProvider);
    final rows = ref.watch(filteredTransactionsProvider);
    final hide = ref.watch(hideAmountsProvider);
    final categories = ref.watch(categoriesByIdProvider);
    final accounts = ref.watch(accountsByIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: l10n.transactionsSearchHint,
                  border: InputBorder.none,
                ),
              )
            : Text(l10n.tabTransactions),
        actions: [
          IconButton(
            tooltip: l10n.transactionsSearchHint,
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: l10n.transactionsFilter,
            onPressed: _openFilters,
            icon: Badge(
              isLabelVisible: query.filter.activeCount > 0,
              label: Text('${query.filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addTransactionTooltip,
        onPressed: () => context.push(RoutePaths.transactionNew),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncSchedulerProvider).syncNow(),
        child: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(l10n.errorGeneric)),
          data: (data) {
            if (data.isEmpty) {
              final filtered = !query.filter.isEmpty;
              return ListView(
                children: [
                  if (!filtered) const PendingConfirmationSection(),
                  SizedBox(
                    height: 360,
                    child: EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: filtered
                          ? l10n.transactionsEmptyFilteredTitle
                          : l10n.transactionsEmptyTitle,
                      message: filtered
                          ? l10n.transactionsEmptyFilteredBody
                          : l10n.transactionsEmptyBody,
                    ),
                  ),
                ],
              );
            }
            final groups = groupByDay(
              data,
              ref.watch(userClockProvider).today(),
            );
            return ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: groups.length + 1,
              itemBuilder: (context, position) {
                // The first item is the section of transactions waiting for
                // confirmation (only without a filter or a search).
                if (position == 0) {
                  return query.filter.isEmpty
                      ? const PendingConfirmationSection()
                      : const SizedBox.shrink();
                }
                final group = groups[position - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatCivilDateLong(group.date),
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                          Text(
                            hide
                                ? formatRupiah(0, hidden: true)
                                : formatRupiah(group.net),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                    for (final transaction in group.transactions)
                      Dismissible(
                        key: ValueKey(transaction.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: theme.colorScheme.errorContainer,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        onDismissed: (_) => unawaited(_delete(transaction)),
                        child: TransactionTile(
                          transaction: transaction,
                          categories: categories,
                          accounts: accounts,
                          hideAmounts: hide,
                          onTap: transaction.type == 'adjustment'
                              ? null
                              : () => context.push(
                                  RoutePaths.transaction(transaction.id),
                                ),
                          onLongPress: () => unawaited(_longPress(transaction)),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
