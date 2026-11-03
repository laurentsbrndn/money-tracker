import 'package:drift/drift.dart' show Value;

import '../../../core/billing/plan_limits.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/validation/validation_exception.dart';

/// Accounts and their opening snapshots. Reads are live streams from the
/// local database; every write goes through the [OutboxWriter]
/// (SYNC_PROTOCOL §6).
class AccountsRepository {
  AccountsRepository({
    required this._db,
    required this._writer,
    required this._isPremium,
    required this._today,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;
  final Future<bool> Function() _isPremium;

  /// "Today" in the user's timezone.
  final CivilDate Function() _today;

  static const IdGenerator _ids = IdGenerator();

  Stream<List<AccountRow>> watchAll() => _db.accountsDao.watchActive();

  Stream<AccountRow?> watchOne(String id) => _db.accountsDao.watchById(id);

  Future<AccountRow?> find(String id) => _db.accountsDao.findById(id);

  Future<bool> hasTransactions(String id) async =>
      await _db.transactionsDao.countForAccount(id) > 0;

  void _validate({
    required String name,
    required int openingBalance,
    required CivilDate openingDate,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException(ValidationError.nameRequired);
    }
    if (trimmed.length > 50) {
      throw const ValidationException(ValidationError.nameTooLong);
    }
    if (openingBalance.abs() > maxAmount) {
      throw const ValidationException(ValidationError.amountRange);
    }
    if (openingDate.isAfter(_today())) {
      throw const ValidationException(ValidationError.openingDateFuture);
    }
  }

  Future<void> _checkAccountLimit() async {
    if (await _isPremium()) {
      return;
    }
    if (await _db.accountsDao.countOpen() >= PlanLimits.maxFreeAccounts) {
      throw const PlanLimitException(PlanLimitKind.accounts);
    }
  }

  /// Creates the account and its first balance snapshot (BUSINESS_RULES §2.3)
  /// in one transaction. Returns the new account id.
  Future<String> create({
    required String name,
    required String type,
    required int openingBalance,
    required CivilDate openingDate,
    String? providerKey,
    bool includeInTotal = true,
  }) async {
    _validate(
      name: name,
      openingBalance: openingBalance,
      openingDate: openingDate,
    );
    await _checkAccountLimit();
    final id = _ids.newId();
    final sortOrder = await _db.accountsDao.maxSortOrder() + 1;
    await _writer.write((tx) async {
      await tx.upsert(
        SyncEntities.accounts,
        id,
        AccountRow(
          id: id,
          createdAt: tx.now,
          updatedAt: tx.now,
          serverVersion: null,
          syncStatus: 'pending',
          name: name.trim(),
          type: type,
          providerKey: providerKey,
          currency: 'IDR',
          openingBalance: openingBalance,
          openingDate: openingDate,
          includeInTotal: includeInTotal,
          sortOrder: sortOrder,
        ),
      );
      final snapshotId = _ids.newId();
      await tx.upsert(
        SyncEntities.balanceSnapshots,
        snapshotId,
        BalanceSnapshotRow(
          id: snapshotId,
          createdAt: tx.now,
          updatedAt: tx.now,
          serverVersion: null,
          syncStatus: 'pending',
          accountId: id,
          snapshotDate: openingDate,
          amount: openingBalance,
        ),
      );
    });
    return id;
  }

  /// Edits the account. A changed opening balance/date also moves the
  /// account's first snapshot so the reconciliation starts from a zero diff.
  Future<void> update(
    AccountRow existing, {
    required String name,
    required String type,
    required int openingBalance,
    required CivilDate openingDate,
    String? providerKey,
    bool includeInTotal = true,
  }) async {
    _validate(
      name: name,
      openingBalance: openingBalance,
      openingDate: openingDate,
    );
    await _writer.write((tx) async {
      await tx.upsert(
        SyncEntities.accounts,
        existing.id,
        existing.copyWith(
          name: name.trim(),
          type: type,
          providerKey: Value(providerKey),
          openingBalance: openingBalance,
          openingDate: openingDate,
          includeInTotal: includeInTotal,
        ),
      );
      final openingChanged =
          openingBalance != existing.openingBalance ||
          openingDate != existing.openingDate;
      if (openingChanged) {
        await _moveInitialSnapshot(
          tx,
          existing,
          openingBalance: openingBalance,
          openingDate: openingDate,
        );
      }
    });
  }

  Future<void> _moveInitialSnapshot(
    OutboxTx tx,
    AccountRow account, {
    required int openingBalance,
    required CivilDate openingDate,
  }) async {
    final snapshots = await _db.balanceSnapshotsDao.allByAccount(account.id);
    for (final snapshot in snapshots) {
      if (snapshot.snapshotDate == account.openingDate &&
          snapshot.amount == account.openingBalance) {
        await tx.upsert(
          SyncEntities.balanceSnapshots,
          snapshot.id,
          snapshot.copyWith(snapshotDate: openingDate, amount: openingBalance),
        );
        return;
      }
    }
  }

  Future<void> setArchived(AccountRow account, {required bool archived}) async {
    if (!archived) {
      await _checkAccountLimit();
    }
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.accounts,
        account.id,
        account.copyWith(archivedAt: Value(archived ? tx.now : null)),
      ),
    );
  }

  /// Deletes the account; only possible while no live transaction uses it.
  Future<void> delete(String id) async {
    if (await hasTransactions(id)) {
      throw const RecordInUseException(isAccount: true);
    }
    await _writer.write((tx) async {
      for (final snapshot in await _db.balanceSnapshotsDao.allByAccount(id)) {
        await tx.delete(SyncEntities.balanceSnapshots, snapshot.id);
      }
      await tx.delete(SyncEntities.accounts, id);
    });
  }
}
