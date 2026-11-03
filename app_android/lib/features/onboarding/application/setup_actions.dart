import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/domain_rules/period.dart';
import '../../../core/notifications/notification_coordinator.dart';
import '../../../core/time/user_clock.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../budget/application/budget_providers.dart';
import '../../budget/domain/budget_goal_input.dart';
import '../../settings/application/user_settings_actions.dart';
import '../data/setup_repository.dart';

part 'setup_actions.g.dart';

@Riverpod(keepAlive: true)
SetupRepository setupRepository(Ref ref) =>
    SetupRepository(ref.watch(appDatabaseProvider));

@riverpod
SetupActions setupActions(Ref ref) => SetupActions(ref);

/// What the wizard does on top of the shared repositories.
class SetupActions {
  SetupActions(this._ref);

  final Ref _ref;

  /// Step 1: sets the Cash account's balance (its opening balance and first
  /// snapshot). Does nothing when the Cash account is missing or unchanged.
  Future<void> saveCashBalance(int balance) async {
    final cash = await _ref.read(setupRepositoryProvider).findCash();
    if (cash == null || cash.openingBalance == balance) {
      return;
    }
    await _ref
        .read(accountsRepositoryProvider)
        .update(
          cash,
          name: cash.name,
          type: cash.type,
          providerKey: cash.providerKey,
          openingBalance: balance,
          openingDate: cash.openingDate,
          includeInTotal: cash.includeInTotal,
        );
  }

  /// Step 3: saves the goal for the current month (nothing is written when it
  /// equals the goal already in force for that month).
  Future<void> saveGoal(BudgetGoalInput input) async {
    final month = YearMonth.of(_ref.read(userClockProvider).today());
    await _ref
        .read(budgetRepositoryProvider)
        .saveGoal(
          month: month,
          needsPct: input.needs,
          wantsPct: input.wants,
          savingsPct: input.savings,
          plannedIncome: input.plannedIncome,
        );
  }

  /// Step 5: turns the daily reminder on at [time] (asking for the notification
  /// permission now, the moment the user opts in). Nothing happens when the
  /// reminder stays off.
  Future<void> saveReminder({
    required bool enabled,
    required String time,
  }) async {
    if (!enabled) {
      return;
    }
    final service = _ref.read(notificationServiceProvider);
    if (!await service.areEnabled()) {
      await service.requestPermission();
    }
    await _ref.read(userSettingsRepositoryProvider).setDailyReminderTime(time);
  }

  Future<void> finish() => _ref.read(setupRepositoryProvider).markDone();
}
