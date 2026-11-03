/// Entity names on the wire (SYNC_PROTOCOL §2).
abstract final class SyncEntities {
  static const String userSettings = 'user_settings';
  static const String categories = 'categories';
  static const String accounts = 'accounts';
  static const String balanceSnapshots = 'balance_snapshots';
  static const String transactions = 'transactions';
  static const String recurringRules = 'recurring_rules';
  static const String budgetGoals = 'budget_goals';

  static const List<String> all = [
    userSettings,
    categories,
    accounts,
    balanceSnapshots,
    transactions,
    recurringRules,
    budgetGoals,
  ];
}
