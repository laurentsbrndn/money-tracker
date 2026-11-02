import 'package:drift/drift.dart';

/// Key-value store: `device_id`, `pull_cursor`, `last_sync_at`, `entitlement`.
@DataClassName('SyncStateEntry')
class SyncState extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
