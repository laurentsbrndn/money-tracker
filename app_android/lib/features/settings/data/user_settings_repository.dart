import 'package:drift/drift.dart' show Value;

import '../../../core/database/app_database.dart';
import '../../../core/sync/outbox_writer.dart';
import '../../../core/sync/sync_entities.dart';
import '../../../core/time/user_clock.dart';
import '../../../core/validation/validation_exception.dart';

/// The user's `user_settings` row (DATA_MODEL §2), which syncs between devices.
/// Device-only preferences (PIN, biometrics, auto-lock) are not here; they
/// live in `core/security`. Every write goes through the [OutboxWriter].
class UserSettingsRepository {
  UserSettingsRepository({required this._db, required this._writer});

  final AppDatabase _db;
  final OutboxWriter _writer;

  static final RegExp _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Rewrites the current row through [change]. Throws while the row has not
  /// been pulled yet (a new account's first sync).
  Future<void> _update(
    UserSettingsRow Function(UserSettingsRow row) change,
  ) async {
    final current = await _db.userSettingsDao.current();
    if (current == null) {
      throw const ValidationException(ValidationError.settingsMissing);
    }
    await _writer.write(
      (tx) => tx.upsert(SyncEntities.userSettings, current.id, change(current)),
    );
  }

  Future<void> setTimezone(String timezone) {
    if (!isValidTimezone(timezone)) {
      throw const ValidationException(ValidationError.timezoneInvalid);
    }
    return _update((row) => row.copyWith(timezone: timezone));
  }

  /// `system`, `light`, or `dark`.
  Future<void> setTheme(String theme) =>
      _update((row) => row.copyWith(theme: theme));

  /// 1 = Monday, 7 = Sunday.
  Future<void> setWeekStart(int weekStart) =>
      _update((row) => row.copyWith(weekStart: weekStart));

  Future<void> setHideAmounts({required bool hide}) =>
      _update((row) => row.copyWith(hideAmounts: hide));

  /// `HH:MM` local time, or null to turn the daily reminder off.
  Future<void> setDailyReminderTime(String? time) {
    if (time != null && !_time.hasMatch(time)) {
      throw const ValidationException(ValidationError.reminderTimeInvalid);
    }
    return _update((row) => row.copyWith(dailyReminderTime: Value(time)));
  }

  Future<void> setReconcileReminder({required bool enabled}) =>
      _update((row) => row.copyWith(reconcileReminderEnabled: enabled));

  Future<void> setBudgetAlert({required bool enabled}) =>
      _update((row) => row.copyWith(budgetAlertEnabled: enabled));
}
