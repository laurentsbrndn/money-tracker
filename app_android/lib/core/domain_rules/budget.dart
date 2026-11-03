import 'dart:math' as math;

import '../time/civil_date.dart';
import 'balance.dart';
import 'period.dart';
import 'rounding.dart';
import 'types.dart';

/// The budget outcome of one bucket (needs, wants, or savings).
class AllocationResult {
  const AllocationResult({
    required this.goalAmount,
    required this.actual,
    required this.remaining,
    this.actualBp,
  });

  final int goalAmount;
  final int actual;

  /// [actual] as basis points of the basis (1941 = 19,41%); null when the
  /// basis is 0.
  final int? actualBp;
  final int remaining;
}

/// The budget of one month (BUSINESS_RULES §4.5).
class Budget {
  const Budget({
    required this.basis,
    required this.needs,
    required this.wants,
    required this.savings,
    required this.unallocated,
  });

  final int basis;
  final AllocationResult needs;
  final AllocationResult wants;
  final AllocationResult savings;
  final int unallocated;
}

/// The goal in force for [month]: the non-deleted goal with the largest
/// effective month that is not after [month]; null when there is none.
BudgetGoal? effectiveGoal(List<BudgetGoal> goals, YearMonth month) {
  BudgetGoal? best;
  for (final goal in goals) {
    if (goal.deleted || goal.effectiveMonth.compareTo(month) > 0) {
      continue;
    }
    if (best == null ||
        goal.effectiveMonth.compareTo(best.effectiveMonth) > 0) {
      best = goal;
    }
  }
  return best;
}

/// BUSINESS_RULES §4.5 for [month].
///
/// Whether an account is a savings account is read from [accounts] at call
/// time, so changing an account's type recomputes history. A transfer to or
/// from an unknown account counts as a non-savings account. With no [goal]
/// all percentages are 0.
Budget computeBudget(
  List<Account> accounts,
  List<Transaction> txs,
  BudgetGoal? goal,
  YearMonth month,
  CivilDate asOf,
) {
  final isSavings = {
    for (final account in accounts)
      account.id: account.type == AccountType.savings,
  };

  var income = 0;
  var needs = 0;
  var wants = 0;
  var savingsExpense = 0;
  var savingsTransfer = 0;
  for (final tx in txs) {
    if (!counts(tx, asOf) || !month.contains(tx.date)) {
      continue;
    }
    switch (tx.type) {
      case TransactionType.income:
        income += tx.amount;
      case TransactionType.expense:
        switch (tx.allocation) {
          case Allocation.needs:
            needs += tx.amount;
          case Allocation.wants:
            wants += tx.amount;
          case Allocation.savings:
            savingsExpense += tx.amount;
          case null:
            break;
        }
      case TransactionType.transfer:
        final from = isSavings[tx.accountId] ?? false;
        final to = isSavings[tx.toAccountId] ?? false;
        if (!from && to) {
          savingsTransfer += tx.amount;
        } else if (from && !to) {
          savingsTransfer -= tx.amount;
        }
      case TransactionType.adjustment:
        break;
    }
  }
  final savings = savingsExpense + savingsTransfer;

  final planned = goal?.plannedIncome ?? 0;
  final basis = math.max(planned, income);

  return Budget(
    basis: basis,
    needs: _allocationResult(basis, goal?.needsPct ?? 0, needs),
    wants: _allocationResult(basis, goal?.wantsPct ?? 0, wants),
    savings: _allocationResult(basis, goal?.savingsPct ?? 0, savings),
    unallocated: basis - needs - wants - savings,
  );
}

AllocationResult _allocationResult(int basis, int pct, int actual) {
  final goalAmount = roundHalfUp(basis * pct, 100);
  return AllocationResult(
    goalAmount: goalAmount,
    actual: actual,
    remaining: goalAmount - actual,
    actualBp: basis == 0 ? null : roundHalfUp(actual * 10000, basis),
  );
}

/// Warning thresholds of BUSINESS_RULES §4.5, in percent of `goal_amount`.
const int budgetWarnPercent = 80;
const int budgetLimitPercent = 100;

/// The highest warning threshold (80 or 100) that [actual] has reached for a
/// bucket with [goalAmount], or null. A goal of 0 never warns.
///
/// Integer arithmetic only: `actual * 100 >= goalAmount * threshold`.
int? budgetAlertLevel(int goalAmount, int actual) {
  if (goalAmount <= 0) {
    return null;
  }
  if (actual * 100 >= goalAmount * budgetLimitPercent) {
    return budgetLimitPercent;
  }
  if (actual * 100 >= goalAmount * budgetWarnPercent) {
    return budgetWarnPercent;
  }
  return null;
}

/// The expense of one category in a month; [categoryId] is null for an
/// expense without a category.
class CategoryTotal {
  const CategoryTotal({required this.categoryId, required this.amount});

  final String? categoryId;
  final int amount;
}

/// What makes up one bucket of the budget (APP_FLOWS Flow 6: "rincian per
/// kategori").
class AllocationBreakdown {
  const AllocationBreakdown({
    required this.categories,
    required this.transferNet,
  });

  /// Expenses of the bucket grouped by category, largest first
  /// (BUSINESS_RULES §4.6).
  final List<CategoryTotal> categories;

  /// Net transfers into savings accounts; 0 for needs and wants. Together with
  /// the category totals it adds up to `actual` of [computeBudget].
  final int transferNet;

  int get total => categories.fold(transferNet, (sum, c) => sum + c.amount);
}

/// The categories behind [allocation] in [month], from the same transactions
/// and rules as [computeBudget].
AllocationBreakdown computeAllocationBreakdown(
  List<Account> accounts,
  List<Transaction> txs,
  Allocation allocation,
  YearMonth month,
  CivilDate asOf,
) {
  final isSavings = {
    for (final account in accounts)
      account.id: account.type == AccountType.savings,
  };
  final byCategory = <String?, int>{};
  var transferNet = 0;
  for (final tx in txs) {
    if (!counts(tx, asOf) || !month.contains(tx.date)) {
      continue;
    }
    switch (tx.type) {
      case TransactionType.expense:
        if (tx.allocation == allocation) {
          byCategory[tx.categoryId] =
              (byCategory[tx.categoryId] ?? 0) + tx.amount;
        }
      case TransactionType.transfer:
        if (allocation == Allocation.savings) {
          final from = isSavings[tx.accountId] ?? false;
          final to = isSavings[tx.toAccountId] ?? false;
          if (!from && to) {
            transferNet += tx.amount;
          } else if (from && !to) {
            transferNet -= tx.amount;
          }
        }
      case TransactionType.income:
      case TransactionType.adjustment:
        break;
    }
  }
  final categories = [
    for (final entry in byCategory.entries)
      CategoryTotal(categoryId: entry.key, amount: entry.value),
  ]..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);
      return byAmount != 0
          ? byAmount
          : (a.categoryId ?? '').compareTo(b.categoryId ?? '');
    });
  return AllocationBreakdown(categories: categories, transferNet: transferNet);
}
