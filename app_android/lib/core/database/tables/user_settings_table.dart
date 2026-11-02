import 'package:drift/drift.dart';

import 'sync_columns.dart';

/// `id` equals the user id (one row per user).
@DataClassName('UserSettingsRow')
class UserSettings extends Table with SyncColumns {
  TextColumn get timezone =>
      text().withDefault(const Constant('Asia/Jakarta'))();

  TextColumn get currency => text().withDefault(const Constant('IDR'))();

  /// 1 = Monday, 7 = Sunday.
  IntColumn get weekStart => integer().withDefault(const Constant(1))();

  /// `system`, `light`, or `dark`.
  TextColumn get theme => text().withDefault(const Constant('system'))();

  /// `HH:MM` local time.
  TextColumn get dailyReminderTime => text().nullable()();

  BoolColumn get reconcileReminderEnabled =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get budgetAlertEnabled =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get hideAmounts => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
