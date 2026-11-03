import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain_rules/period.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/time/civil_date_format.dart';
import '../../../../core/time/user_clock.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../application/budget_providers.dart';
import '../../domain/budget_goal_input.dart';
import '../widgets/budget_goal_form.dart';

/// Atur goal (APP_FLOWS Flow 6 step 1): percentages, presets, planned income,
/// effective from the current month.
class BudgetGoalScreen extends ConsumerStatefulWidget {
  const BudgetGoalScreen({super.key});

  @override
  ConsumerState<BudgetGoalScreen> createState() => _BudgetGoalScreenState();
}

class _BudgetGoalScreenState extends ConsumerState<BudgetGoalScreen> {
  BudgetGoalInput? _input;
  bool _busy = false;

  Future<void> _save(YearMonth month) async {
    final input = _input;
    if (input == null || !input.isValid) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(budgetRepositoryProvider)
          .saveGoal(
            month: month,
            needsPct: input.needs,
            wantsPct: input.wants,
            savingsPct: input.savings,
            plannedIncome: input.plannedIncome,
          );
      messenger.showSnackBar(SnackBar(content: Text(l10n.budgetGoalSaved)));
      router.pop();
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goal = ref.watch(currentGoalProvider);
    final month = YearMonth.of(ref.watch(userClockProvider).today());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetGoalTitle)),
      body: goal.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(l10n.errorGeneric)),
        data: (current) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.budgetGoalIntro),
            const SizedBox(height: 4),
            Text(l10n.budgetGoalEffective(formatYearMonth(month))),
            const SizedBox(height: 16),
            BudgetGoalForm(
              initial: current == null
                  ? BudgetGoalInput.standard
                  : BudgetGoalInput(
                      needs: current.needsPct,
                      wants: current.wantsPct,
                      savings: current.savingsPct,
                      plannedIncome: current.plannedIncome,
                    ),
              onChanged: (value) => setState(() => _input = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy || !(_input?.isValid ?? true)
                  ? null
                  : () => _save(month),
              child: Text(l10n.actionSave),
            ),
          ],
        ),
      ),
    );
  }
}
