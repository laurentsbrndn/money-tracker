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

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  DateTimeColumn get nextAttemptAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
