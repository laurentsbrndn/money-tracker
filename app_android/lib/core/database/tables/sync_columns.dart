import 'package:drift/drift.dart';

/// Columns shared by every synced entity table (DATA_MODEL §1.1 without the
/// server-only columns, plus the local columns of SYNC_PROTOCOL §5.1).
mixin SyncColumns on Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  IntColumn get serverVersion => integer().nullable()();

  /// `synced`, `pending`, or `failed`.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// Why the server refused the row (`code: message`) while [syncStatus] is
  /// `failed`; shown under "Perlu perhatian".
  TextColumn get syncError => text().nullable()();
}
