import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/tables/sync_columns.dart';

/// Local access to one synced entity table, in the terms the sync engine
/// needs. One generic implementation serves all seven tables because they
/// share [SyncColumns].
abstract class EntityStore {
  /// The row as wire JSON, or null if it does not exist locally.
  Future<Map<String, Object?>?> rowJson(String id);

  Future<int?> serverVersionOf(String id);

  Future<DateTime?> updatedAtOf(String id);

  /// Writes a whole row from the app, stamped `pending` with [updatedAt].
  Future<void> saveLocal(Insertable<Object?> row, DateTime updatedAt);

  /// Writes a row received from the server (`synced`).
  Future<void> saveFromServer(Map<String, Object?> json, int serverVersion);

  Future<void> markDeleted(String id, DateTime at);

  /// Marks the row as changed again (`pending`, new `updated_at`) without
  /// altering its data, so it can be re-queued.
  Future<void> touch(String id, DateTime at);

  Future<void> deleteHard(String id);

  Future<void> markSynced(String id, int? serverVersion);

  Future<void> markFailed(String id, String error);

  /// Count of rows in `failed` state.
  Future<List<String>> failedIds();
}

class TableEntityStore<T extends SyncColumns, D> implements EntityStore {
  TableEntityStore({
    required this._db,
    required TableInfo<Table, D> table,
    required this._toJson,
    required this._fromJson,
  }) : _table = table as TableInfo<T, D>;

  final AppDatabase _db;
  final TableInfo<T, D> _table;
  final Map<String, Object?> Function(D row) _toJson;
  final Insertable<D> Function(Map<String, Object?> json, int version)
  _fromJson;

  SimpleSelectStatement<T, D> _byId(String id) =>
      _db.select(_table)..where((t) => t.id.equals(id));

  Future<void> _write(String id, Map<String, Expression<Object>> values) =>
      (_db.update(
        _table,
      )..where((t) => t.id.equals(id))).write(RawValuesInsertable<D>(values));

  @override
  Future<Map<String, Object?>?> rowJson(String id) async {
    final row = await _byId(id).getSingleOrNull();
    return row == null ? null : _toJson(row);
  }

  @override
  Future<int?> serverVersionOf(String id) async {
    final query = _db.selectOnly(_table)
      ..addColumns([_table.asDslTable.serverVersion])
      ..where(_table.asDslTable.id.equals(id));
    final row = await query.getSingleOrNull();
    return row?.read(_table.asDslTable.serverVersion);
  }

  @override
  Future<DateTime?> updatedAtOf(String id) async {
    final query = _db.selectOnly(_table)
      ..addColumns([_table.asDslTable.updatedAt])
      ..where(_table.asDslTable.id.equals(id));
    final row = await query.getSingleOrNull();
    return row?.read(_table.asDslTable.updatedAt);
  }

  @override
  Future<void> saveLocal(Insertable<Object?> row, DateTime updatedAt) {
    final columns = Map<String, Expression>.of(
      (row as Insertable<D>).toColumns(false),
    );
    columns['updated_at'] = Variable<DateTime>(updatedAt);
    columns['sync_status'] = const Variable<String>('pending');
    columns['sync_error'] = const Variable<String>(null);
    return _db
        .into(_table)
        .insertOnConflictUpdate(RawValuesInsertable<D>(columns));
  }

  @override
  Future<void> saveFromServer(Map<String, Object?> json, int serverVersion) =>
      _db.into(_table).insertOnConflictUpdate(_fromJson(json, serverVersion));

  @override
  Future<void> markDeleted(String id, DateTime at) => _write(id, {
    'deleted_at': Variable<DateTime>(at),
    'updated_at': Variable<DateTime>(at),
    'sync_status': const Variable<String>('pending'),
    'sync_error': const Variable<String>(null),
  });

  @override
  Future<void> touch(String id, DateTime at) => _write(id, {
    'updated_at': Variable<DateTime>(at),
    'sync_status': const Variable<String>('pending'),
    'sync_error': const Variable<String>(null),
  });

  @override
  Future<void> deleteHard(String id) =>
      (_db.delete(_table)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> markSynced(String id, int? serverVersion) => _write(id, {
    'sync_status': const Variable<String>('synced'),
    'sync_error': const Variable<String>(null),
    if (serverVersion != null) 'server_version': Variable<int>(serverVersion),
  });

  @override
  Future<void> markFailed(String id, String error) => _write(id, {
    'sync_status': const Variable<String>('failed'),
    'sync_error': Variable<String>(error),
  });

  @override
  Future<List<String>> failedIds() async {
    final rows = await (_db.select(
      _table,
    )..where((t) => t.syncStatus.equals('failed'))).get();
    return [for (final row in rows) (_toJson(row)['id']! as String)];
  }
}
