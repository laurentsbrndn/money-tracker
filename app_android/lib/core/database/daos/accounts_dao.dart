import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.attachedDatabase);

  /// Live rows (archived included), tombstones excluded, in list order.
  Stream<List<AccountRow>> watchActive() =>
      (select(accounts)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  Stream<AccountRow?> watchById(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<List<AccountRow>> allActive() =>
      (select(accounts)..where((t) => t.deletedAt.isNull())).get();

  /// Live, not archived: what the free-plan limit counts.
  Future<int> countOpen() async {
    final count = accounts.id.count();
    final row =
        await (selectOnly(accounts)
              ..addColumns([count])
              ..where(
                accounts.deletedAt.isNull() & accounts.archivedAt.isNull(),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> maxSortOrder() async {
    final maximum = accounts.sortOrder.max();
    final row = await (selectOnly(accounts)..addColumns([maximum])).getSingle();
    return row.read(maximum) ?? -1;
  }

  Future<AccountRow?> findById(String id) =>
      (select(accounts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(AccountsCompanion row) =>
      into(accounts).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(accounts)..where((t) => t.id.equals(id))).write(
        AccountsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(accounts)..where((t) => t.id.equals(id))).go();

  Stream<List<AccountRow>> watchOpen() =>
      (select(accounts)
            ..where((t) => t.deletedAt.isNull() & t.archivedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .watch();
}
