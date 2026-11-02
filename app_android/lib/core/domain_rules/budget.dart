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
