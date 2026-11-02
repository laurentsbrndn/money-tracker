import 'package:drift/drift.dart';

import '../converters/civil_date_converter.dart';
import 'sync_columns.dart';

@DataClassName('AccountRow')
class Accounts extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// `bank`, `e_wallet`, `cash`, or `savings`.
  TextColumn get type => text()();

  TextColumn get providerKey => text().nullable()();

  TextColumn get currency => text().withDefault(const Constant('IDR'))();

  /// May be negative.
  Int64Column get openingBalance => int64()();

  TextColumn get openingDate => text().map(const CivilDateConverter())();

  BoolColumn get includeInTotal =>
      boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer()();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
