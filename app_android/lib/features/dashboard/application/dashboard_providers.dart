import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/billing/entitlement_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/database/mappers/row_mappers.dart';
import '../../../core/domain_rules/balance.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/time/today.dart';
import '../../accounts/application/accounts_providers.dart';

part 'dashboard_providers.g.dart';

/// The month shown on the dashboard; starts at the current month.
@Riverpod(keepAlive: true)
class SelectedMonth extends _$SelectedMonth {
  @override
  YearMonth build() => YearMonth.of(todayCivil());

  void select(YearMonth month) => state = month;
}

/// The oldest month a free user may open: the current month plus the two
/// before it (BUSINESS_RULES §7).
YearMonth oldestFreeMonth() => YearMonth.of(todayCivil()).addMonths(-2);

@riverpod
bool canViewMonth(Ref ref, YearMonth month) {
  final premium = ref.watch(isPremiumProvider).value ?? false;
  return premium || month.compareTo(oldestFreeMonth()) >= 0;
}

/// Live transactions of one month. Declared by hand because it returns a
/// Drift row type.
final monthTransactionsProvider = StreamProvider.autoDispose
    .family<List<TransactionRow>, YearMonth>(
      (ref, month) => ref
          .watch(appDatabaseProvider)
          .transactionsDao
          .watchBetween(month.first, month.last),
    );

/// The five newest transactions.
final recentTransactionsProvider =
    StreamProvider.autoDispose<List<TransactionRow>>(
      (ref) => ref
          .watch(appDatabaseProvider)
          .transactionsDao
          .watchFiltered(limit: 5),
    );

/// Income, expense and surplus of [month] from `core/domain_rules`.
@riverpod
Future<MonthlySummary> monthlySummary(Ref ref, YearMonth month) async {
  final accounts = await ref.watch(allAccountsProvider.future);
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  return computeMonthlySummary(
    [for (final account in accounts) account.toDomain()],
    [for (final row in transactions) row.toDomain()],
    month,
    todayCivil(),
  );
}

/// Whether the user has recorded anything at all (drives the empty state).
final hasAnyTransactionProvider = Provider.autoDispose<bool>(
  (ref) => (ref.watch(recentTransactionsProvider).value ?? const []).isNotEmpty,
);
