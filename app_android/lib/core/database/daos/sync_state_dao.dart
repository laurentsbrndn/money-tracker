import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sync_state_table.dart';

part 'sync_state_dao.g.dart';

@DriftAccessor(tables: [SyncState])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.attachedDatabase);

  Future<String?> read(String key) async {
    final row = await (select(
      syncState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Stream<String?> watch(String key) =>
      (select(syncState)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);

  Future<void> write(String key, String value) => into(
    syncState,
  ).insertOnConflictUpdate(SyncStateCompanion.insert(key: key, value: value));

  Future<void> remove(String key) =>
      (delete(syncState)..where((t) => t.key.equals(key))).go();

  /// Every key-value pair, re-emitted on change.
  Stream<Map<String, String>> watchAll() =>
      select(syncState)
          .watch()
          .map((rows) => {for (final row in rows) row.key: row.value});
}
