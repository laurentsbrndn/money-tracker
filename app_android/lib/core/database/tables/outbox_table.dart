import 'package:drift/drift.dart';

@DataClassName('OutboxEntry')
class Outbox extends Table {
  IntColumn get seq => integer().autoIncrement()();

  TextColumn get entity => text()();

  TextColumn get recordId => text()();

  /// `upsert` or `delete`.
  TextColumn get op => text()();

  /// Whole row as JSON for `upsert`; empty for `delete`.
  TextColumn get payload => text().withDefault(const Constant(''))();

  DateTimeColumn get updatedAt => dateTime()();

  /// "In flight" marker (SYNC_PROTOCOL §5.2.1): the `Idempotency-Key` of the
  /// batch carrying this entry; null while the entry has not been sent.
  TextColumn get batchId => text().nullable()();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
