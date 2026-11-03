import '../../../core/database/app_database.dart';
import '../../../core/ids/id_generator.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/civil_date.dart';
import '../../../core/validation/validation_exception.dart';
import '../domain/transaction_draft.dart';
import '../domain/transaction_filter.dart';

/// Transactions: reads are live streams from the local database; every write
/// goes through the [OutboxWriter] (SYNC_PROTOCOL §6). Rules from
/// BUSINESS_RULES §6 are checked before saving; the server repeats them.
class TransactionsRepository {
  TransactionsRepository({
    required this._db,
    required this._writer,
    required this._today,
  });

  final AppDatabase _db;
  final OutboxWriter _writer;

  /// "Today" in the user's timezone.
  final CivilDate Function() _today;

  static const IdGenerator _ids = IdGenerator();

  Stream<List<TransactionRow>> watchFiltered(
    TransactionFilter filter,
    int limit,
  ) => _db.transactionsDao.watchFiltered(
    limit: limit,
    type: filter.type,
    accountId: filter.accountId,
    categoryId: filter.categoryId,
    allocation: filter.allocation,
    from: filter.from,
    to: filter.to,
    query: filter.query,
  );

  Future<TransactionRow?> find(String id) => _db.transactionsDao.findById(id);

  /// The admin fee expenses linked to a transfer.
  Future<List<TransactionRow>> feesOf(String transferId) =>
      _db.transactionsDao.linkedTo(transferId);

  Future<List<String>> recentSources() => _db.transactionsDao.recentSources();

  Future<String?> lastAccountId(String type) =>
      _db.transactionsDao.lastAccountId(type);

  Future<AccountRow> _requireAccount(
    String? id,
    ValidationError missing,
  ) async {
    final account = id == null ? null : await _db.accountsDao.findById(id);
    if (account == null || account.deletedAt != null) {
      throw ValidationException(missing);
    }
    return account;
  }

  /// Validates [draft] and saves it (and, for a transfer, its admin fee).
  /// Returns the transaction id.
  Future<String> save(TransactionDraft draft) async {
    final amount = draft.amount;
    if (amount == null) {
      throw const ValidationException(ValidationError.amountRequired);
    }
    if (amount <= 0) {
      throw const ValidationException(ValidationError.amountZero);
    }
    if (amount > maxAmount) {
      throw const ValidationException(ValidationError.amountRange);
    }
    if (draft.date.isAfter(_today().addDays(366))) {
      throw const ValidationException(ValidationError.dateFuture);
    }
    final note = draft.note?.trim();
    if ((note?.length ?? 0) > 255) {
      throw const ValidationException(ValidationError.noteTooLong);
    }
    final source = draft.source?.trim();
    if ((source?.length ?? 0) > 100) {
      throw const ValidationException(ValidationError.sourceTooLong);
    }
    final account = await _requireAccount(
      draft.accountId,
      ValidationError.accountRequired,
    );
    if (draft.date.isBefore(account.openingDate)) {
      throw const ValidationException(ValidationError.dateBeforeOpening);
    }

    String? toAccountId;
    String? categoryId;
    String? allocation;
    switch (draft.type) {
      case 'transfer':
        if (draft.toAccountId == null) {
          throw const ValidationException(ValidationError.toAccountRequired);
        }
        if (draft.toAccountId == draft.accountId) {
          throw const ValidationException(ValidationError.sameAccount);
        }
        final target = await _requireAccount(
          draft.toAccountId,
          ValidationError.toAccountRequired,
        );
        if (draft.date.isBefore(target.openingDate)) {
          throw const ValidationException(ValidationError.dateBeforeOpening);
        }
        toAccountId = target.id;
      case 'expense':
        if (draft.categoryId == null) {
          throw const ValidationException(ValidationError.categoryRequired);
        }
        if (draft.allocation == null) {
          throw const ValidationException(ValidationError.allocationRequired);
        }
        categoryId = draft.categoryId;
        allocation = draft.allocation;
      case 'income':
        categoryId = draft.categoryId;
    }
    final fee = draft.type == 'transfer' ? draft.fee : null;
    if (fee != null && (fee <= 0 || fee > maxAmount)) {
      throw const ValidationException(ValidationError.amountRange);
    }
    final feeCategory = fee == null
        ? null
        : await _db.categoriesDao.findFeeCategory();
    if (fee != null && feeCategory == null) {
      throw const ValidationException(ValidationError.categoryRequired);
    }

    final existing = draft.existing;
    final id = existing?.id ?? _ids.newId();
    await _writer.write((tx) async {
      await tx.upsert(
        SyncEntities.transactions,
        id,
        TransactionRow(
          id: id,
          createdAt: existing?.createdAt ?? tx.now,
          updatedAt: tx.now,
          serverVersion: existing?.serverVersion,
          syncStatus: 'pending',
          type: draft.type,
          // Saving a transaction that waits for confirmation records it
          // (APP_FLOWS Flow 10: amount and date may be changed first).
          status: 'posted',
          transactionDate: draft.date,
          amount: amount,
          currency: 'IDR',
          accountId: account.id,
          toAccountId: toAccountId,
          categoryId: categoryId,
          allocation: allocation,
          source: draft.type == 'income' && (source ?? '').isNotEmpty
              ? source
              : null,
          note: (note ?? '').isEmpty ? null : note,
          linkedTransactionId: existing?.linkedTransactionId,
          recurringRuleId: existing?.recurringRuleId,
        ),
      );
      if (draft.type == 'transfer') {
        await _saveFee(
          tx,
          transferId: id,
          fee: fee,
          feeCategory: feeCategory,
          accountId: account.id,
          date: draft.date,
        );
      }
    });
    return id;
  }

  /// Creates, updates, or deletes the admin fee expense of a transfer so it
  /// matches [fee] (null/absent = no fee).
  Future<void> _saveFee(
    OutboxTx tx, {
    required String transferId,
    required int? fee,
    required CategoryRow? feeCategory,
    required String accountId,
    required CivilDate date,
  }) async {
    final existing = await _db.transactionsDao.linkedTo(transferId);
    if (fee == null) {
      for (final row in existing) {
        await tx.delete(SyncEntities.transactions, row.id);
      }
      return;
    }
    final previous = existing.isEmpty ? null : existing.first;
    final feeId = previous?.id ?? _ids.newId();
    await tx.upsert(
      SyncEntities.transactions,
      feeId,
      TransactionRow(
        id: feeId,
        createdAt: previous?.createdAt ?? tx.now,
        updatedAt: tx.now,
        serverVersion: previous?.serverVersion,
        syncStatus: 'pending',
        type: 'expense',
        status: 'posted',
        transactionDate: date,
        amount: fee,
        currency: 'IDR',
        accountId: accountId,
        categoryId: feeCategory!.id,
        allocation: feeCategory.defaultAllocation ?? 'needs',
        linkedTransactionId: transferId,
      ),
    );
  }

  /// "Catat": records a transaction of a `confirm` rule as it is.
  Future<void> confirm(String id) async {
    final row = await _db.transactionsDao.findById(id);
    if (row == null ||
        row.deletedAt != null ||
        row.status != 'pending_confirmation') {
      return;
    }
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.transactions,
        id,
        row.copyWith(
          status: 'posted',
          updatedAt: tx.now,
          syncStatus: 'pending',
        ),
      ),
    );
  }

  /// Deletes the transaction (and the admin fees linked to a transfer).
  /// Returns what was removed so the delete can be undone.
  Future<List<TransactionRow>> delete(String id) async {
    final row = await _db.transactionsDao.findById(id);
    if (row == null || row.deletedAt != null) {
      return const [];
    }
    final removed = [row, ...await _db.transactionsDao.linkedTo(id)];
    await _writer.write((tx) async {
      for (final item in removed.reversed) {
        await tx.delete(SyncEntities.transactions, item.id);
      }
    });
    return removed;
  }

  /// Undo of [delete]: writes the rows back, transfer before its fees.
  Future<void> restore(List<TransactionRow> removed) =>
      _writer.write((tx) async {
        for (final row in removed) {
          await tx.upsert(SyncEntities.transactions, row.id, row);
        }
      });

  /// Copies the transaction as a new one dated today and returns its id.
  Future<String?> duplicate(String id) async {
    final source = await _db.transactionsDao.findById(id);
    if (source == null) {
      return null;
    }
    final copyId = _ids.newId();
    await _writer.write(
      (tx) => tx.upsert(
        SyncEntities.transactions,
        copyId,
        TransactionRow(
          id: copyId,
          createdAt: tx.now,
          updatedAt: tx.now,
          syncStatus: 'pending',
          type: source.type,
          status: 'posted',
          transactionDate: _today(),
          amount: source.amount,
          currency: source.currency,
          accountId: source.accountId,
          toAccountId: source.toAccountId,
          categoryId: source.categoryId,
          allocation: source.allocation,
          source: source.source,
          note: source.note,
        ),
      ),
    );
    return copyId;
  }
}
