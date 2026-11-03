import 'package:drift/drift.dart';

import '../time/civil_date.dart';
import 'converters/civil_date_converter.dart';
import 'daos/accounts_dao.dart';
import 'daos/balance_snapshots_dao.dart';
import 'daos/budget_goals_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/outbox_dao.dart';
import 'daos/recurring_rules_dao.dart';
import 'daos/sync_state_dao.dart';
import 'daos/transactions_dao.dart';
import 'daos/user_settings_dao.dart';
import 'tables/accounts_table.dart';
import 'tables/balance_snapshots_table.dart';
import 'tables/budget_goals_table.dart';
import 'tables/categories_table.dart';
import 'tables/outbox_table.dart';
import 'tables/recurring_rules_table.dart';
import 'tables/sync_state_table.dart';
import 'tables/transactions_table.dart';
import 'tables/user_settings_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    UserSettings,
    Accounts,
    BalanceSnapshots,
    Categories,
    Transactions,
    RecurringRules,
    BudgetGoals,
    Outbox,
    SyncState,
  ],
  daos: [
    UserSettingsDao,
    AccountsDao,
    BalanceSnapshotsDao,
    CategoriesDao,
    TransactionsDao,
    RecurringRulesDao,
    BudgetGoalsDao,
    OutboxDao,
    SyncStateDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  /// All local migrations live here, one step per [schemaVersion].
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {},
  );
}
