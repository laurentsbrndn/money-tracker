import 'package:drift/drift.dart';

import '../converters/civil_date_converter.dart';
import 'sync_columns.dart';

@DataClassName('RecurringRuleRow')
class RecurringRules extends Table with SyncColumns {
  /// `income`, `expense`, or `transfer`.
  TextColumn get type => text()();

  IntColumn get amount => integer()();

  TextColumn get accountId => text()();

  TextColumn get toAccountId => text().nullable()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get allocation => text().nullable()();

  TextColumn get source => text().nullable()();

  TextColumn get note => text().nullable()();

  /// `daily`, `weekly`, `monthly`, or `yearly`.
  TextColumn get frequency => text()();

  IntColumn get intervalCount => integer().withDefault(const Constant(1))();

  /// 1-7 (Monday-Sunday), for `weekly`.
  IntColumn get dayOfWeek => integer().nullable()();

  /// 1-31, for `monthly` and `yearly`.
  IntColumn get dayOfMonth => integer().nullable()();

  /// 1-12, for `yearly`.
  IntColumn get monthOfYear => integer().nullable()();

  TextColumn get startDate => text().map(const CivilDateConverter())();

  TextColumn get endDate => text().map(const CivilDateConverter()).nullable()();

  /// `auto` or `confirm`.
  TextColumn get mode => text()();

  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();

  TextColumn get lastGeneratedDate =>
      text().map(const CivilDateConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
