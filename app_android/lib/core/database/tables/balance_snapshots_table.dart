import 'package:drift/drift.dart';

import '../converters/civil_date_converter.dart';
import 'sync_columns.dart';

@DataClassName('BalanceSnapshotRow')
@TableIndex(
  name: 'balance_snapshots_account_date',
  columns: {#accountId, #snapshotDate},
)
class BalanceSnapshots extends Table with SyncColumns {
  TextColumn get accountId => text()();

  TextColumn get snapshotDate => text().map(const CivilDateConverter())();

  IntColumn get amount => integer()();

  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
