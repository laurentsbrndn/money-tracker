import 'package:drift/drift.dart';

import 'sync_columns.dart';

@DataClassName('CategoryRow')
@TableIndex(name: 'categories_type', columns: {#type})
class Categories extends Table with SyncColumns {
  /// `expense` or `income`.
  TextColumn get type => text()();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  TextColumn get icon => text()();

  /// `#RRGGBB`.
  TextColumn get color => text()();

  /// `needs`, `wants`, or `savings`; required for expense, null for income.
  TextColumn get defaultAllocation => text().nullable()();

  IntColumn get sortOrder => integer()();

  BoolColumn get isDefault => boolean()();

  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
