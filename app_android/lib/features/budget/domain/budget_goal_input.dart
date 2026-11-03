/// A goal as typed in the form; valid when the three percentages are 0-100
/// and add up to 100 (BUSINESS_RULES §6).
class BudgetGoalInput {
  const BudgetGoalInput({
    required this.needs,
    required this.wants,
    required this.savings,
    this.plannedIncome,
  });

  /// The default split of a new account (BUSINESS_RULES §2.2).
  static const BudgetGoalInput standard = BudgetGoalInput(
    needs: 50,
    wants: 30,
    savings: 20,
  );

  final int needs;
  final int wants;
  final int savings;
  final int? plannedIncome;

  int get total => needs + wants + savings;

  bool get isValid =>
      total == 100 &&
      [needs, wants, savings].every((pct) => pct >= 0 && pct <= 100);
}

/// Presets offered next to the form (APP_FLOWS Flow 6 step 1).
const List<(int, int, int)> budgetGoalPresets = [
  (50, 30, 20),
  (60, 20, 20),
  (40, 30, 30),
];
