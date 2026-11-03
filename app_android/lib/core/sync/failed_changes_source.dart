import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'failed_change.dart';
import 'sync_entities.dart';

/// Reads every row whose last push was refused for good, across all synced
/// tables.
class FailedChangesSource {
  const FailedChangesSource(this._db);

  final AppDatabase _db;

  Future<List<FailedChange>> load() async {
    final result = <FailedChange>[];
    for (final row in await (_db.select(
      _db.accounts,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.accounts,
          recordId: row.id,
          title: row.name,
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.categories,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.categories,
          recordId: row.id,
          title: row.name,
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.transactions,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.transactions,
          recordId: row.id,
          title: row.note ?? row.source ?? '',
          amount: row.amount,
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.balanceSnapshots,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.balanceSnapshots,
          recordId: row.id,
          title: row.note ?? '',
          amount: row.amount,
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.userSettings,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.userSettings,
          recordId: row.id,
          title: '',
          error: row.syncError ?? '',
          isDelete: false,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.budgetGoals,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.budgetGoals,
          recordId: row.id,
          title: row.effectiveMonth.toString(),
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    for (final row in await (_db.select(
      _db.recurringRules,
    )..where((t) => t.syncStatus.equals('failed'))).get()) {
      result.add(
        FailedChange(
          entity: SyncEntities.recurringRules,
          recordId: row.id,
          title: row.note ?? '',
          amount: row.amount,
          error: row.syncError ?? '',
          isDelete: row.deletedAt != null,
        ),
      );
    }
    return result;
  }

  /// Emits the current list, then again after any synced table changes.
  Stream<List<FailedChange>> watch() async* {
    yield await load();
    final updates = _db.tableUpdates(
      TableUpdateQuery.onAllTables([
        _db.accounts,
        _db.categories,
        _db.transactions,
        _db.balanceSnapshots,
        _db.userSettings,
        _db.budgetGoals,
        _db.recurringRules,
      ]),
    );
    await for (final _ in updates) {
      yield await load();
    }
  }
}
