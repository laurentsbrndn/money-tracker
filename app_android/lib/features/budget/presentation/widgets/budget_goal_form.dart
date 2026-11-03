import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/budget_goal_input.dart';

/// The goal form shared by the goal screen and the setup wizard: three
/// percentages (total 100), presets, and the optional planned income.
/// [onChanged] fires on every edit with the current input.
class BudgetGoalForm extends StatefulWidget {
  const BudgetGoalForm({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final BudgetGoalInput initial;
  final ValueChanged<BudgetGoalInput> onChanged;

  @override
  State<BudgetGoalForm> createState() => _BudgetGoalFormState();
}

class _BudgetGoalFormState extends State<BudgetGoalForm> {
  late final TextEditingController _needs;
  late final TextEditingController _wants;
  late final TextEditingController _savings;
  late final TextEditingController _planned;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _needs = TextEditingController(text: '${initial.needs}');
    _wants = TextEditingController(text: '${initial.wants}');
    _savings = TextEditingController(text: '${initial.savings}');
    _planned = TextEditingController();
    final planned = initial.plannedIncome;
    if (planned != null && planned > 0) {
      _planned.text = groupThousands(planned);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _needs.dispose();
    _wants.dispose();
    _savings.dispose();
    _planned.dispose();
    super.dispose();
  }

  int _pct(TextEditingController controller) =>
      int.tryParse(controller.text) ?? 0;

  BudgetGoalInput get _input => BudgetGoalInput(
    needs: _pct(_needs),
    wants: _pct(_wants),
    savings: _pct(_savings),
    plannedIncome: MoneyField.valueOf(_planned),
  );

  void _emit() {
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged(_input);
  }

  void _applyPreset((int, int, int) preset) {
    _needs.text = '${preset.$1}';
    _wants.text = '${preset.$2}';
    _savings.text = '${preset.$3}';
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final input = _input;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.budgetGoalPresets, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in budgetGoalPresets)
              ActionChip(
                label: Text('${preset.$1}/${preset.$2}/${preset.$3}'),
                onPressed: () => _applyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _pctField(_needs, l10n.budgetGoalNeeds)),
            const SizedBox(width: 12),
            Expanded(child: _pctField(_wants, l10n.budgetGoalWants)),
            const SizedBox(width: 12),
            Expanded(child: _pctField(_savings, l10n.budgetGoalSavings)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.budgetGoalTotal(input.total),
          style: theme.textTheme.titleSmall?.copyWith(
            color: input.isValid ? AppColors.income : theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 16),
        MoneyField(
          controller: _planned,
          label: l10n.budgetGoalPlanned,
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 4),
        Text(l10n.budgetGoalPlannedHint, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _pctField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _emit(),
      );
}
