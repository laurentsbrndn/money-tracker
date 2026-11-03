import 'package:drift/drift.dart';

import '../converters/civil_date_converter.dart';
import 'sync_columns.dart';

/// `id` is deterministic: UUIDv5 of the user id and the month (see SYNC_PROTOCOL §3).
@DataClassName('BudgetGoalRow')
@TableIndex(name: 'budget_goals_effective_month', columns: {#effectiveMonth})
class BudgetGoals extends Table with SyncColumns {
  /// Always the first day of the month.
  TextColumn get effectiveMonth => text().map(const CivilDateConverter())();

  IntColumn get needsPct => integer()();

  IntColumn get wantsPct => integer()();

  IntColumn get savingsPct => integer()();

  IntColumn get plannedIncome => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
