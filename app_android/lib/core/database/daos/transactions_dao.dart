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

  /// Whether a live, posted transaction is dated [date] (the daily reminder is
  /// skipped on such a day).
  Future<bool> hasPostedOn(CivilDate date) async {
    final row =
        await (select(transactions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.status.equals('posted') &
                    t.transactionDate.isBiggerOrEqualValue(date.toString()) &
                    t.transactionDate.isSmallerOrEqualValue(date.toString()),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Every live transaction (needed by the balance formulas).
  Stream<List<TransactionRow>> watchAllActive() =>
      (select(transactions)..where((t) => t.deletedAt.isNull())).watch();

  Future<List<TransactionRow>> allActive() =>
      (select(transactions)..where((t) => t.deletedAt.isNull())).get();

  /// Live transactions in the history list, newest first, [limit] rows
  /// (paged by growing the limit).
  Stream<List<TransactionRow>> watchFiltered({
    required int limit,
    String? type,
    String? accountId,
    String? categoryId,
    String? allocation,
    CivilDate? from,
    CivilDate? to,
    String? query,
  }) =>
      (select(transactions)
            ..where((t) {
              Expression<bool> condition = t.deletedAt.isNull();
              if (type != null) {
                condition = condition & t.type.equals(type);
              }
              if (accountId != null) {
                condition =
                    condition &
                    (t.accountId.equals(accountId) |
                        t.toAccountId.equals(accountId));
              }
              if (categoryId != null) {
                condition = condition & t.categoryId.equals(categoryId);
              }
              if (allocation != null) {
                condition = condition & t.allocation.equals(allocation);
              }
              if (from != null) {
                condition =
                    condition &
                    t.transactionDate.isBiggerOrEqualValue(from.toString());
              }
              if (to != null) {
                condition =
                    condition &
                    t.transactionDate.isSmallerOrEqualValue(to.toString());
              }
              final text = query?.trim() ?? '';
              if (text.isNotEmpty) {
                condition =
                    condition &
                    (t.note.contains(text) | t.source.contains(text));
              }
              return condition;
            })
            ..orderBy([
              (t) => OrderingTerm.desc(t.transactionDate),
              (t) => OrderingTerm.desc(t.createdAt),
            ])
            ..limit(limit))
          .watch();

  /// Live transactions that still reference the account (as source or
  /// destination): such an account can only be archived (BUSINESS_RULES §6).
  Future<int> countForAccount(String accountId) async {
    final count = transactions.id.count();
    final row =
        await (selectOnly(transactions)
              ..addColumns([count])
              ..where(
                transactions.deletedAt.isNull() &
                    (transactions.accountId.equals(accountId) |
                        transactions.toAccountId.equals(accountId)),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countForCategory(String categoryId) async {
    final count = transactions.id.count();
    final row =
        await (selectOnly(transactions)
              ..addColumns([count])
              ..where(
                transactions.deletedAt.isNull() &
                    transactions.categoryId.equals(categoryId),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// The account used by the most recent transaction of [type]: the default
  /// pick in the entry form (APP_FLOWS Flow 3).
  Future<String?> lastAccountId(String type) async {
    final row =
        await (select(transactions)
              ..where((t) => t.deletedAt.isNull() & t.type.equals(type))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row?.accountId;
  }

  /// Recent distinct income sources, for suggestions.
  Future<List<String>> recentSources({int limit = 8}) async {
    final rows =
        await (select(transactions)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.type.equals('income') &
                    t.source.isNotNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(60))
            .get();
    final seen = <String>[];
    for (final row in rows) {
      final source = row.source!.trim();
      if (source.isNotEmpty && !seen.contains(source)) {
        seen.add(source);
        if (seen.length == limit) {
          break;
        }
      }
    }
    return seen;
  }

  /// Live fee expenses linked to a transfer.
  Future<List<TransactionRow>> linkedTo(String transferId) =>
      (select(transactions)..where(
            (t) =>
                t.deletedAt.isNull() & t.linkedTransactionId.equals(transferId),
          ))
          .get();
}
