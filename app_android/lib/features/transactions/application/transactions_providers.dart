import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/time/user_clock.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_filter.dart';

part 'transactions_providers.g.dart';

const int _pageSize = 50;

@Riverpod(keepAlive: true)
TransactionsRepository transactionsRepository(Ref ref) =>
    TransactionsRepository(
      db: ref.watch(appDatabaseProvider),
      writer: ref.watch(outboxWriterProvider),
      today: () => ref.read(userClockProvider).today(),
    );

/// Filter and page size of the history list. The list is paged by growing
/// the limit as the user scrolls; a new filter starts again at one page.
class TransactionListQuery {
  const TransactionListQuery({
    this.filter = const TransactionFilter(),
    this.limit = _pageSize,
  });

  final TransactionFilter filter;
  final int limit;
}

@Riverpod(keepAlive: true)
class TransactionListController extends _$TransactionListController {
  @override
  TransactionListQuery build() => const TransactionListQuery();

  void setFilter(TransactionFilter filter) =>
      state = TransactionListQuery(filter: filter);

  void setQuery(String query) => setFilter(state.filter.copyWith(query: query));

  void loadMore() => state = TransactionListQuery(
    filter: state.filter,
    limit: state.limit + _pageSize,
  );
}

/// Rows for the history list. Declared by hand because it returns a Drift row
/// type.
final filteredTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionRow>>((ref) {
      final query = ref.watch(transactionListControllerProvider);
      return ref
          .watch(transactionsRepositoryProvider)
          .watchFiltered(query.filter, query.limit);
    });
