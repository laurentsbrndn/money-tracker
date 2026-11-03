import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/balance_snapshots_table.dart';

part 'balance_snapshots_dao.g.dart';

@DriftAccessor(tables: [BalanceSnapshots])
class BalanceSnapshotsDao extends DatabaseAccessor<AppDatabase>
    with _$BalanceSnapshotsDaoMixin {
  BalanceSnapshotsDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<BalanceSnapshotRow>> watchActive() =>
      (select(balanceSnapshots)..where((t) => t.deletedAt.isNull())).watch();

  Future<BalanceSnapshotRow?> findById(String id) => (select(
    balanceSnapshots,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(BalanceSnapshotsCompanion row) =>
      into(balanceSnapshots).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(balanceSnapshots)..where((t) => t.id.equals(id))).write(
        BalanceSnapshotsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(balanceSnapshots)..where((t) => t.id.equals(id))).go();

  /// Every live snapshot of one account, oldest date first.
  Future<List<BalanceSnapshotRow>> allByAccount(String accountId) =>
      (select(balanceSnapshots)
            ..where((t) => t.deletedAt.isNull() & t.accountId.equals(accountId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.snapshotDate),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .get();

  Stream<List<BalanceSnapshotRow>> watchByAccount(String accountId) =>
      (select(balanceSnapshots)
            ..where((t) => t.deletedAt.isNull() & t.accountId.equals(accountId))
            ..orderBy([
              (t) => OrderingTerm.desc(t.snapshotDate),
              (t) => OrderingTerm.desc(t.updatedAt),
            ]))
          .watch();
}
