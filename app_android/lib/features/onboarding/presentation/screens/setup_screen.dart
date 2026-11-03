import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money_formatter.dart';
import '../../../../core/network/error_messages.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/theme/provider_logos.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../budget/domain/budget_goal_input.dart';
import '../../../categories/application/categories_providers.dart';
import '../../../settings/application/user_settings_providers.dart';
import '../../application/setup_actions.dart';
import '../widgets/setup_goal_step.dart';
import '../widgets/setup_lock_step.dart';
import '../widgets/setup_notification_step.dart';

/// Setup wizard for new users (APP_FLOWS Flow 1, step 6): Cash balance,
/// extra accounts, budget goal, hide categories, daily reminder, and PIN lock.
/// Can be skipped at any time.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const int _stepCount = 6;

  final _cash = TextEditingController();
  BudgetGoalInput? _goal;
  bool _reminderOn = true;
  String _reminderTime = '20:00';
  int _step = 0;
  bool _busy = false;

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (_step == 0) {
        final value = MoneyField.valueOf(_cash);
        if (value != null) {
          await ref.read(setupActionsProvider).saveCashBalance(value);
        }
      }
      if (_step == 2) {
        final goal = _goal;
        if (goal != null && goal.isValid) {
          await ref.read(setupActionsProvider).saveGoal(goal);
        }
      }
      if (_step == 4) {
        await ref
            .read(setupActionsProvider)
            .saveReminder(enabled: _reminderOn, time: _reminderTime);
      }
      if (_step == _stepCount - 1) {
        await _finish();
        return;
      }
      if (mounted) {
        setState(() {
          _step++;
          _busy = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _busy = false);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(error, l10n))),
      );
    }
  }

  Future<void> _finish() async {
    await ref.read(setupActionsProvider).finish();
    if (mounted) {
      context.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final titles = [
      l10n.setupStepCash,
      l10n.setupStepAccounts,
      l10n.setupStepGoal,
      l10n.setupStepCategories,
      l10n.setupStepNotifications,
      l10n.setupStepLock,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.setupTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _busy ? null : _finish,
            child: Text(l10n.setupSkipAll),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / _stepCount),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_step) {
                0 => _CashStep(controller: _cash),
                1 => const _AccountsStep(),
                2 => SetupGoalStep(onChanged: (value) => _goal = value),
                3 => const _CategoriesStep(),
                4 => SetupNotificationStep(
                  enabled: _reminderOn,
                  time: _reminderTime,
                  onEnabledChanged: (value) =>
                      setState(() => _reminderOn = value),
                  onTimeChanged: (value) =>
                      setState(() => _reminderTime = value),
                ),
                _ => const SetupLockStep(),
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _step--),
                      child: Text(l10n.actionBack),
                    ),
                  const Spacer(),
                  Text(
                    '${_step + 1}/$_stepCount · ${titles[_step]}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _next,
                    child: Text(
                      _step == _stepCount - 1
                          ? l10n.setupFinish
                          : l10n.actionContinue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashStep extends StatelessWidget {
  const _CashStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.setupCashTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupCashBody),
        const SizedBox(height: 24),
        MoneyField(
          controller: controller,
          label: l10n.accountFieldOpeningBalance,
          autofocus: true,
        ),
      ],
    );
  }
}

class _AccountsStep extends ConsumerWidget {
  const _AccountsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accounts = ref.watch(accountBalancesProvider).value ?? const [];
    final hide = ref.watch(hideAmountsProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.setupAccountsTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupAccountsBody),
        const SizedBox(height: 16),
        for (final item in accounts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ProviderLogo(providerKey: item.account.providerKey),
            title: Text(item.account.name),
            trailing: Text(formatRupiah(item.expectedBalance, hidden: hide)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push(RoutePaths.accountNew),
          icon: const Icon(Icons.add),
          label: Text(l10n.setupAccountsAdd),
        ),
      ],
    );
  }
}

class _CategoriesStep extends ConsumerWidget {
  const _CategoriesStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(allCategoriesProvider).value ?? const [];
    final repository = ref.watch(categoriesRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.setupCategoriesTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l10n.setupCategoriesBody),
        const SizedBox(height: 8),
        for (final type in const ['expense', 'income']) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              type == 'expense'
                  ? l10n.categoryTypeExpense
                  : l10n.categoryTypeIncome,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final category in categories.where((c) => c.type == type))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                CategoryIcons.of(category.icon),
                color: CategoryIcons.colorOf(category.color),
              ),
              title: Text(category.name),
              value: !category.isHidden,
              onChanged: (visible) =>
                  repository.setHidden(category, hidden: !visible),
            ),
        ],
      ],
    );
  }
}
