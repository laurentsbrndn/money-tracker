import 'package:drift/drift.dart';

import '../../time/civil_date.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<TransactionRow>> watchActive() =>
      (select(transactions)..where((t) => t.deletedAt.isNull())).watch();

  Future<TransactionRow?> findById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(TransactionsCompanion row) =>
      into(transactions).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(transactions)..where((t) => t.id.equals(id))).write(
        TransactionsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Live rows with `from <= transaction_date <= to`, newest first.
  Stream<List<TransactionRow>> watchBetween(CivilDate from, CivilDate to) =>
      (select(transactions)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.transactionDate.isBiggerOrEqualValue(from.toString()) &
                  t.transactionDate.isSmallerOrEqualValue(to.toString()),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.transactionDate),
              (t) => OrderingTerm.desc(t.createdAt),
            ]))
          .watch();
}
