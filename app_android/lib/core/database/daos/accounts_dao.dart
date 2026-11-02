import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<AccountRow>> watchActive() =>
      (select(accounts)..where((t) => t.deletedAt.isNull())).watch();

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
