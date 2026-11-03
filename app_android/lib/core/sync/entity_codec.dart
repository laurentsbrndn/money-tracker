import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../time/civil_date.dart';
import '../time/timestamp_format.dart';

/// Rows ↔ the snake_case JSON of SYNC_PROTOCOL §4. Rows are always sent
/// whole, every nullable key present as `null` when empty. Server-only columns
/// (`user_id`, `server_version`, `server_updated_at`) are never sent.
class EntityCodec {
  const EntityCodec();

  static String? _ts(DateTime? value) =>
      value == null ? null : formatTimestamp(value);

  static DateTime? _readTs(Object? value) =>
      value == null ? null : parseTimestamp(value as String);

  static DateTime _requireTs(Object? value) => parseTimestamp(value! as String);

  static int _int(Object? value) => (value! as num).toInt();

  static int? _intOrNull(Object? value) => (value as num?)?.toInt();

  static CivilDate _date(Object? value) => CivilDate.parse(value! as String);

  static CivilDate? _dateOrNull(Object? value) =>
      value == null ? null : CivilDate.parse(value as String);

  Map<String, Object?> userSettingsToJson(UserSettingsRow r) => {
    'id': r.id,
    'timezone': r.timezone,
    'currency': r.currency,
    'week_start': r.weekStart,
    'theme': r.theme,
    'daily_reminder_time': r.dailyReminderTime,
    'reconcile_reminder_enabled': r.reconcileReminderEnabled,
    'budget_alert_enabled': r.budgetAlertEnabled,
    'hide_amounts': r.hideAmounts,
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  UserSettingsCompanion userSettingsFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => UserSettingsCompanion(
    id: Value(j['id']! as String),
    timezone: Value(j['timezone']! as String),
    currency: Value(j['currency'] as String? ?? 'IDR'),
    weekStart: Value(_int(j['week_start'])),
    theme: Value(j['theme']! as String),
    dailyReminderTime: Value(j['daily_reminder_time'] as String?),
    reconcileReminderEnabled: Value(j['reconcile_reminder_enabled']! as bool),
    budgetAlertEnabled: Value(j['budget_alert_enabled']! as bool),
    hideAmounts: Value(j['hide_amounts']! as bool),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> categoryToJson(CategoryRow r) => {
    'id': r.id,
    'type': r.type,
    'name': r.name,
    'icon': r.icon,
    'color': r.color,
    'default_allocation': r.defaultAllocation,
    'sort_order': r.sortOrder,
    'is_default': r.isDefault,
    'is_hidden': r.isHidden,
    'archived_at': _ts(r.archivedAt),
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  CategoriesCompanion categoryFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => CategoriesCompanion(
    id: Value(j['id']! as String),
    type: Value(j['type']! as String),
    name: Value(j['name']! as String),
    icon: Value(j['icon']! as String),
    color: Value(j['color']! as String),
    defaultAllocation: Value(j['default_allocation'] as String?),
    sortOrder: Value(_int(j['sort_order'])),
    isDefault: Value(j['is_default']! as bool),
    isHidden: Value(j['is_hidden'] as bool? ?? false),
    archivedAt: Value(_readTs(j['archived_at'])),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> accountToJson(AccountRow r) => {
    'id': r.id,
    'name': r.name,
    'type': r.type,
    'provider_key': r.providerKey,
    'currency': r.currency,
    'opening_balance': r.openingBalance,
    'opening_date': r.openingDate.toString(),
    'include_in_total': r.includeInTotal,
    'sort_order': r.sortOrder,
    'archived_at': _ts(r.archivedAt),
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  AccountsCompanion accountFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => AccountsCompanion(
    id: Value(j['id']! as String),
    name: Value(j['name']! as String),
    type: Value(j['type']! as String),
    providerKey: Value(j['provider_key'] as String?),
    currency: Value(j['currency'] as String? ?? 'IDR'),
    openingBalance: Value(_int(j['opening_balance'])),
    openingDate: Value(_date(j['opening_date'])),
    includeInTotal: Value(j['include_in_total'] as bool? ?? true),
    sortOrder: Value(_int(j['sort_order'])),
    archivedAt: Value(_readTs(j['archived_at'])),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> balanceSnapshotToJson(BalanceSnapshotRow r) => {
    'id': r.id,
    'account_id': r.accountId,
    'snapshot_date': r.snapshotDate.toString(),
    'amount': r.amount,
    'note': r.note,
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  BalanceSnapshotsCompanion balanceSnapshotFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => BalanceSnapshotsCompanion(
    id: Value(j['id']! as String),
    accountId: Value(j['account_id']! as String),
    snapshotDate: Value(_date(j['snapshot_date'])),
    amount: Value(_int(j['amount'])),
    note: Value(j['note'] as String?),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> transactionToJson(TransactionRow r) => {
    'id': r.id,
    'type': r.type,
    'status': r.status,
    'transaction_date': r.transactionDate.toString(),
    'amount': r.amount,
    'currency': r.currency,
    'account_id': r.accountId,
    'to_account_id': r.toAccountId,
    'category_id': r.categoryId,
    'allocation': r.allocation,
    'source': r.source,
    'note': r.note,
    'linked_transaction_id': r.linkedTransactionId,
    'recurring_rule_id': r.recurringRuleId,
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  TransactionsCompanion transactionFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => TransactionsCompanion(
    id: Value(j['id']! as String),
    type: Value(j['type']! as String),
    status: Value(j['status'] as String? ?? 'posted'),
    transactionDate: Value(_date(j['transaction_date'])),
    amount: Value(_int(j['amount'])),
    currency: Value(j['currency'] as String? ?? 'IDR'),
    accountId: Value(j['account_id']! as String),
    toAccountId: Value(j['to_account_id'] as String?),
    categoryId: Value(j['category_id'] as String?),
    allocation: Value(j['allocation'] as String?),
    source: Value(j['source'] as String?),
    note: Value(j['note'] as String?),
    linkedTransactionId: Value(j['linked_transaction_id'] as String?),
    recurringRuleId: Value(j['recurring_rule_id'] as String?),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> recurringRuleToJson(RecurringRuleRow r) => {
    'id': r.id,
    'type': r.type,
    'amount': r.amount,
    'account_id': r.accountId,
    'to_account_id': r.toAccountId,
    'category_id': r.categoryId,
    'allocation': r.allocation,
    'source': r.source,
    'note': r.note,
    'frequency': r.frequency,
    'interval_count': r.intervalCount,
    'day_of_week': r.dayOfWeek,
    'day_of_month': r.dayOfMonth,
    'month_of_year': r.monthOfYear,
    'start_date': r.startDate.toString(),
    'end_date': r.endDate?.toString(),
    'mode': r.mode,
    'is_paused': r.isPaused,
    'last_generated_date': r.lastGeneratedDate?.toString(),
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  RecurringRulesCompanion recurringRuleFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => RecurringRulesCompanion(
    id: Value(j['id']! as String),
    type: Value(j['type']! as String),
    amount: Value(_int(j['amount'])),
    accountId: Value(j['account_id']! as String),
    toAccountId: Value(j['to_account_id'] as String?),
    categoryId: Value(j['category_id'] as String?),
    allocation: Value(j['allocation'] as String?),
    source: Value(j['source'] as String?),
    note: Value(j['note'] as String?),
    frequency: Value(j['frequency']! as String),
    intervalCount: Value(_intOrNull(j['interval_count']) ?? 1),
    dayOfWeek: Value(_intOrNull(j['day_of_week'])),
    dayOfMonth: Value(_intOrNull(j['day_of_month'])),
    monthOfYear: Value(_intOrNull(j['month_of_year'])),
    startDate: Value(_date(j['start_date'])),
    endDate: Value(_dateOrNull(j['end_date'])),
    mode: Value(j['mode']! as String),
    isPaused: Value(j['is_paused'] as bool? ?? false),
    lastGeneratedDate: Value(_dateOrNull(j['last_generated_date'])),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );

  Map<String, Object?> budgetGoalToJson(BudgetGoalRow r) => {
    'id': r.id,
    'effective_month': r.effectiveMonth.toString(),
    'needs_pct': r.needsPct,
    'wants_pct': r.wantsPct,
    'savings_pct': r.savingsPct,
    'planned_income': r.plannedIncome,
    'created_at': _ts(r.createdAt),
    'updated_at': _ts(r.updatedAt),
    'deleted_at': _ts(r.deletedAt),
  };

  BudgetGoalsCompanion budgetGoalFromJson(
    Map<String, Object?> j,
    int serverVersion,
  ) => BudgetGoalsCompanion(
    id: Value(j['id']! as String),
    effectiveMonth: Value(_date(j['effective_month'])),
    needsPct: Value(_int(j['needs_pct'])),
    wantsPct: Value(_int(j['wants_pct'])),
    savingsPct: Value(_int(j['savings_pct'])),
    plannedIncome: Value(_intOrNull(j['planned_income'])),
    createdAt: Value(_requireTs(j['created_at'])),
    updatedAt: Value(_requireTs(j['updated_at'])),
    deletedAt: Value(_readTs(j['deleted_at'])),
    serverVersion: Value(serverVersion),
    syncStatus: const Value('synced'),
    syncError: const Value(null),
  );
}
