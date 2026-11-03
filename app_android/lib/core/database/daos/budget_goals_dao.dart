import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/budget_goals_table.dart';

part 'budget_goals_dao.g.dart';

@DriftAccessor(tables: [BudgetGoals])
class BudgetGoalsDao extends DatabaseAccessor<AppDatabase>
    with _$BudgetGoalsDaoMixin {
  BudgetGoalsDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<BudgetGoalRow>> watchActive() =>
      (select(budgetGoals)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<BudgetGoalRow>> allActive() =>
      (select(budgetGoals)..where((t) => t.deletedAt.isNull())).get();

  Future<BudgetGoalRow?> findById(String id) =>
      (select(budgetGoals)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(BudgetGoalsCompanion row) =>
      into(budgetGoals).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(budgetGoals)..where((t) => t.id.equals(id))).write(
        BudgetGoalsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(budgetGoals)..where((t) => t.id.equals(id))).go();
}
