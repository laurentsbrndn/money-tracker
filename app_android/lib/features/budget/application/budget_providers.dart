import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/database/mappers/row_mappers.dart';
import '../../../core/domain_rules/budget.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/domain_rules/types.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/time/user_clock.dart';
import '../../accounts/application/accounts_providers.dart';
import '../data/budget_repository.dart';
import '../domain/month_budget.dart';

part 'budget_providers.g.dart';

@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) => BudgetRepository(
  db: ref.watch(appDatabaseProvider),
  writer: ref.watch(outboxWriterProvider),
  userId: () => ref.read(sessionControllerProvider).user?.id,
);

/// Every live goal row. Declared by hand because it holds Drift rows.
final budgetGoalsProvider = StreamProvider.autoDispose<List<BudgetGoalRow>>(
  (ref) => ref.watch(budgetRepositoryProvider).watchAll(),
);

/// The budget of [month] (BUSINESS_RULES §4.5) from `core/domain_rules`.
final monthBudgetProvider = FutureProvider.autoDispose
    .family<MonthBudget, YearMonth>((ref, month) async {
      final accounts = await ref.watch(allAccountsProvider.future);
      final transactions = await ref.watch(allTransactionsProvider.future);
      final goalRows = await ref.watch(budgetGoalsProvider.future);
      final asOf = ref.watch(userClockProvider).today();
      final goal = effectiveGoal([for (final r in goalRows) r.toDomain()], month);
      final budget = computeBudget(
        [for (final row in accounts) row.toDomain()],
        [for (final row in transactions) row.toDomain()],
        goal,
        month,
        asOf,
      );
      return MonthBudget(month: month, asOf: asOf, budget: budget, goal: goal);
    });

/// The categories behind one bucket of [month].
final allocationBreakdownProvider = FutureProvider.autoDispose
    .family<AllocationBreakdown, (YearMonth, Allocation)>((ref, key) async {
      final accounts = await ref.watch(allAccountsProvider.future);
      final transactions = await ref.watch(allTransactionsProvider.future);
      return computeAllocationBreakdown(
        [for (final row in accounts) row.toDomain()],
        [for (final row in transactions) row.toDomain()],
        key.$2,
        key.$1,
        ref.watch(userClockProvider).today(),
      );
    });

/// The goal that applies to the current month, to prefill the goal form.
final currentGoalProvider = FutureProvider.autoDispose<BudgetGoal?>((ref) async {
  final rows = await ref.watch(budgetGoalsProvider.future);
  final month = YearMonth.of(ref.watch(userClockProvider).today());
  return effectiveGoal([for (final r in rows) r.toDomain()], month);
});
