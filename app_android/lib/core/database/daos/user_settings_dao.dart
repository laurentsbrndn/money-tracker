import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/user_settings_table.dart';

part 'user_settings_dao.g.dart';

@DriftAccessor(tables: [UserSettings])
class UserSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserSettingsDaoMixin {
  UserSettingsDao(super.attachedDatabase);

  /// Live rows, tombstones excluded.
  Stream<List<UserSettingsRow>> watchActive() =>
      (select(userSettings)..where((t) => t.deletedAt.isNull())).watch();

  Future<UserSettingsRow?> findById(String id) =>
      (select(userSettings)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Includes tombstones; used by the sync engine.
  Future<void> upsert(UserSettingsCompanion row) =>
      into(userSettings).insertOnConflictUpdate(row);

  Future<void> markDeleted(String id, DateTime at) =>
      (update(userSettings)..where((t) => t.id.equals(id))).write(
        UserSettingsCompanion(deletedAt: Value(at), updatedAt: Value(at)),
      );

  Future<void> deleteHard(String id) =>
      (delete(userSettings)..where((t) => t.id.equals(id))).go();
}
