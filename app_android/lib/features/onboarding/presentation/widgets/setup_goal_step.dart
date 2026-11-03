import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../budget/application/budget_providers.dart';
import '../../../budget/domain/budget_goal_input.dart';
import '../../../budget/presentation/widgets/budget_goal_form.dart';

/// Setup wizard step: the needs/wants/savings goal (APP_FLOWS Flow 1 step
/// 6.3). Starts from the goal the server seeded (50/30/20).
class SetupGoalStep extends ConsumerWidget {
  const SetupGoalStep({required this.onChanged, super.key});

  final ValueChanged<BudgetGoalInput> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final goal = ref.watch(currentGoalProvider);
    return goal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text(l10n.errorGeneric)),
      data: (current) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.setupGoalTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(l10n.setupGoalBody),
          const SizedBox(height: 24),
          BudgetGoalForm(
            initial: current == null
                ? BudgetGoalInput.standard
                : BudgetGoalInput(
                    needs: current.needsPct,
                    wants: current.wantsPct,
                    savings: current.savingsPct,
                    plannedIncome: current.plannedIncome,
                  ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
