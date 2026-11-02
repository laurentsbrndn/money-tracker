import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/recurring_rules_table.dart';

part 'recurring_rules_dao.g.dart';

@DriftAccessor(tables: [RecurringRules])
class RecurringRulesDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringRulesDaoMixin {
  RecurringRulesDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<RecurringRuleRow>> watchActive() =>
      (select(recurringRules)..where((t) => t.deletedAt.isNull())).watch();

  Future<RecurringRuleRow?> findById(String id) =>
      (select(recurringRules)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(RecurringRulesCompanion row) =>
      into(recurringRules).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(recurringRules)..where((t) => t.id.equals(id))).write(
        RecurringRulesCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(recurringRules)..where((t) => t.id.equals(id))).go();
}
