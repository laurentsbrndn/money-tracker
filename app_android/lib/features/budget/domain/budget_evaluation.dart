import '../../../core/domain_rules/types.dart';
import 'month_budget.dart';

/// How a bucket ended against its goal.
enum EvaluationOutcome {
  /// Needs/wants stayed within the goal, or savings reached it.
  good,

  /// Needs/wants went over the goal, or savings fell short of it.
  bad,

  /// No goal amount to compare with (no goal, or no income basis).
  unknown,
}

class AllocationEvaluation {
  const AllocationEvaluation(this.allocation, this.outcome);

  final Allocation allocation;
  final EvaluationOutcome outcome;
}

/// The month-end evaluation card (APP_FLOWS Flow 6 step 3): needs and wants
/// should stay at or under their goal, savings should reach it.
List<AllocationEvaluation> evaluateMonth(MonthBudget month) {
  return [
    for (final allocation in Allocation.values)
      AllocationEvaluation(allocation, _outcome(month, allocation)),
  ];
}

EvaluationOutcome _outcome(MonthBudget month, Allocation allocation) {
  final result = month.resultOf(allocation);
  if (result.goalAmount <= 0) {
    return EvaluationOutcome.unknown;
  }
  final reached = result.actual >= result.goalAmount;
  final good = allocation == Allocation.savings
      ? reached
      : result.actual <= result.goalAmount;
  return good ? EvaluationOutcome.good : EvaluationOutcome.bad;
}

/// Whether the evaluation card is shown: the month is over, or it is within
/// the last 3 days of the month.
bool showsEvaluation(MonthBudget month) =>
    month.asOf.isAfter(month.month.last) ||
    month.asOf.daysSince(month.month.last) >= -2;
