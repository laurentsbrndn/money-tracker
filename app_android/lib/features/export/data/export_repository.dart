import '../../../core/database/app_database.dart';
import '../../../core/domain_rules/types.dart';
import '../domain/export_period.dart';
import '../domain/export_row.dart';

/// Reads the rows of an export from the local database (offline-first, no
/// endpoint). Only posted, live transactions come back: pending
/// confirmations and tombstones are never exported.
class ExportRepository {
  ExportRepository({required this._db});

  final AppDatabase _db;

  Future<List<ExportRow>> loadRows(ExportPeriod period) async {
    final rows = await _db.transactionsDao.postedBetween(
      period.from,
      period.to,
    );
    final accounts = {
      for (final account in await _db.accountsDao.allActive())
        account.id: account.name,
    };
    final categories = {
      for (final category in await _db.categoriesDao.allActive())
        category.id: category.name,
    };
    return [
      for (final row in rows)
        ExportRow(
          date: row.transactionDate,
          type: TransactionType.fromValue(row.type),
          amount: row.amount,
          accountName: accounts[row.accountId] ?? '-',
          toAccountName: row.toAccountId == null
              ? null
              : accounts[row.toAccountId] ?? '-',
          categoryName: row.categoryId == null
              ? null
              : categories[row.categoryId],
          note: row.note,
        ),
    ];
  }
}
