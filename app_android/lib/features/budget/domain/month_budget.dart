import '../../../core/domain_rules/budget.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/domain_rules/types.dart';
import '../../../core/time/civil_date.dart';

/// The budget of one month with the goal in force and the date it was
/// computed for.
class MonthBudget {
  const MonthBudget({
    required this.month,
    required this.asOf,
    required this.budget,
    this.goal,
  });

  final YearMonth month;
  final CivilDate asOf;
  final Budget budget;

  /// The goal in force for [month]; null while none has been set.
  final BudgetGoal? goal;

  AllocationResult resultOf(Allocation allocation) => switch (allocation) {
    Allocation.needs => budget.needs,
    Allocation.wants => budget.wants,
    Allocation.savings => budget.savings,
  };

  int pctOf(Allocation allocation) => switch (allocation) {
    Allocation.needs => goal?.needsPct ?? 0,
    Allocation.wants => goal?.wantsPct ?? 0,
    Allocation.savings => goal?.savingsPct ?? 0,
  };
}
