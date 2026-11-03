import '../../domain_rules/budget.dart';
import '../../domain_rules/period.dart';
import '../../domain_rules/types.dart';

/// A budget warning to show now.
class BudgetAlert {
  const BudgetAlert({
    required this.allocation,
    required this.level,
    required this.goalAmount,
    required this.actual,
  });

  final Allocation allocation;

  /// 80 or 100 (percent of the goal).
  final int level;
  final int goalAmount;
  final int actual;
}

/// The key remembered once a threshold has been announced for a month.
String budgetAlertKey(YearMonth month, Allocation allocation, int level) =>
    '$month|${allocation.value}|$level';

/// What to announce and what to remember (BUSINESS_RULES §4.5): needs and
/// wants warn when they reach 80% and then 100% of their goal, at most once
/// per threshold per month.
class BudgetAlertPlan {
  const BudgetAlertPlan({required this.alerts, required this.keysToRemember});

  final List<BudgetAlert> alerts;

  /// Every threshold up to the announced level, so jumping straight past 80%
  /// does not announce it again later.
  final Set<String> keysToRemember;
}

BudgetAlertPlan planBudgetAlerts({
  required YearMonth month,
  required Budget budget,
  required Set<String> alreadyAnnounced,
}) {
  final alerts = <BudgetAlert>[];
  final keys = <String>{};
  final buckets = {
    Allocation.needs: budget.needs,
    Allocation.wants: budget.wants,
  };
  for (final entry in buckets.entries) {
    final level = budgetAlertLevel(entry.value.goalAmount, entry.value.actual);
    if (level == null) {
      continue;
    }
    final reached = [
      for (final threshold in [budgetWarnPercent, budgetLimitPercent])
        if (threshold <= level) threshold,
    ];
    final fresh = [
      for (final threshold in reached)
        if (!alreadyAnnounced.contains(
          budgetAlertKey(month, entry.key, threshold),
        ))
          threshold,
    ];
    if (fresh.isEmpty) {
      continue;
    }
    alerts.add(
      BudgetAlert(
        allocation: entry.key,
        level: fresh.last,
        goalAmount: entry.value.goalAmount,
        actual: entry.value.actual,
      ),
    );
    for (final threshold in reached) {
      keys.add(budgetAlertKey(month, entry.key, threshold));
    }
  }
  return BudgetAlertPlan(alerts: alerts, keysToRemember: keys);
}
