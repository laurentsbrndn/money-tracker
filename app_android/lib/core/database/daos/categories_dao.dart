import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<CategoryRow>> watchActive() =>
      (select(categories)..where((t) => t.deletedAt.isNull())).watch();

  Future<CategoryRow?> findById(String id) =>
      (select(categories)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(CategoriesCompanion row) =>
      into(categories).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  Stream<List<CategoryRow>> watchByType(String type) =>
      (select(categories)
            ..where((t) => t.deletedAt.isNull() & t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();
}
