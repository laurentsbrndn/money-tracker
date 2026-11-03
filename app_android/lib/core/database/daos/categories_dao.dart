import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/categories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.attachedDatabase);

  /// Live rows, tombstones excluded, in list order.
  Stream<List<CategoryRow>> watchActive() =>
      (select(categories)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.type),
              (t) => OrderingTerm.asc(t.sortOrder),
            ]))
          .watch();

  Future<List<CategoryRow>> allActive() =>
      (select(categories)..where((t) => t.deletedAt.isNull())).get();

  /// Custom categories (not seeded) that are not deleted; archived ones still
  /// count towards the free-plan limit (BUSINESS_RULES §6).
  Future<int> countCustom() async {
    final count = categories.id.count();
    final row =
        await (selectOnly(categories)
              ..addColumns([count])
              ..where(
                categories.deletedAt.isNull() &
                    categories.isDefault.equals(false),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> maxSortOrder(String type) async {
    final maximum = categories.sortOrder.max();
    final row =
        await (selectOnly(categories)
              ..addColumns([maximum])
              ..where(categories.type.equals(type)))
            .getSingle();
    return row.read(maximum) ?? 0;
  }

  /// The seeded fee category used for transfer admin fees (BUSINESS_RULES §2.1).
  Future<CategoryRow?> findFeeCategory() =>
      (select(categories)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.icon.equals('fee') &
                  t.isDefault.equals(true),
            )
            ..limit(1))
          .getSingleOrNull();

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
