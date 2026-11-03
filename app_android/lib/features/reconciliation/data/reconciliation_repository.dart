import '../../../core/database/app_database.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/validation/validation_exception.dart';

/// Writes balance snapshots and adjustments of the reconcile flow
/// (APP_FLOWS Flow 5). Every write goes through the [OutboxWriter].
class ReconciliationRepository {
  ReconciliationRepository({
    required this._db,
    required this._writer,
    required this._today,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;

  /// "Today" in the user's timezone.
  final CivilDate Function() _today;

  static const IdGenerator _ids = IdGenerator();

  Future<AccountRow> _requireAccount(String id) async {
    final account = await _db.accountsDao.findById(id);
    if (account == null || account.deletedAt != null) {
      throw const ValidationException(ValidationError.accountRequired);
    }
    return account;
  }

  /// Saves the observed real balances as snapshots dated today, all in one
  /// transaction. A balance equal to the account's snapshot of today is not
  /// saved twice. Returns the ids of the accounts that now have a snapshot
  /// dated today.
  Future<List<String>> saveSnapshots(Map<String, int> balances) async {
    final today = _today();
    final accounts = <AccountRow>[];
    for (final entry in balances.entries) {
      final account = await _requireAccount(entry.key);
      if (entry.value.abs() > maxAmount) {
        throw const ValidationException(ValidationError.amountRange);
      }
      if (today.isBefore(account.openingDate)) {
        throw const ValidationException(ValidationError.snapshotDateInvalid);
      }
      accounts.add(account);
    }
    final saved = <String>[];
    await _writer.write((tx) async {
      for (final account in accounts) {
        final amount = balances[account.id]!;
        final existing = await _db.balanceSnapshotsDao.allByAccount(account.id);
        final sameDay = existing.where((s) => s.snapshotDate == today).toList();
        // allByAccount is oldest first, so the last one of the day wins.
        final latestOfDay = sameDay.isEmpty ? null : sameDay.last;
        if (latestOfDay == null || latestOfDay.amount != amount) {
          final id = _ids.newId();
          await tx.upsert(
            SyncEntities.balanceSnapshots,
            id,
            BalanceSnapshotRow(
              id: id,
              createdAt: tx.now,
              updatedAt: tx.now,
              serverVersion: null,
              syncStatus: 'pending',
              accountId: account.id,
              snapshotDate: today,
              amount: amount,
            ),
          );
        }
        saved.add(account.id);
      }
    });
    return saved;
  }

  /// Records a signed `adjustment` for the difference between the observed
  /// and the expected balance (BUSINESS_RULES §6: only account, amount, date
  /// and note are set).
  Future<String> createAdjustment({
    required String accountId,
    required int amount,
    required CivilDate date,
    required String note,
  }) async {
    if (amount == 0) {
      throw const ValidationException(ValidationError.adjustmentZero);
    }
    if (amount.abs() > maxAmount) {
      throw const ValidationException(ValidationError.amountRange);
    }
    final account = await _requireAccount(accountId);
    if (date.isBefore(account.openingDate)) {
      throw const ValidationException(ValidationError.dateBeforeOpening);
    }
    final id = _ids.newId();
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.transactions,
        id,
        TransactionRow(
          id: id,
          createdAt: tx.now,
          updatedAt: tx.now,
          serverVersion: null,
          syncStatus: 'pending',
          type: 'adjustment',
          status: 'posted',
          transactionDate: date,
          amount: amount,
          currency: 'IDR',
          accountId: account.id,
          note: note,
        ),
      ),
    );
    return id;
  }
}
