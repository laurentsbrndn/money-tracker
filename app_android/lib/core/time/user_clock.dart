import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../database/app_database_provider.dart';
import 'civil_date.dart';

/// Timezone used before the first `user_settings` row has been pulled; it is
/// also the server default (DATA_MODEL §2).
const String defaultTimezone = 'Asia/Jakarta';

/// Whether [name] is an IANA name known to the bundled timezone database.
/// `initializeTimeZones()` must have run (see `bootstrap()`).
bool isValidTimezone(String name) {
  try {
    tz.getLocation(name);
    return true;
  } on tz.LocationNotFoundException {
    return false;
  }
}

/// The calendar date of [instant] in [location]: port of `Today` in
/// `backend/internal/domainrules/period.go` (BUSINESS_RULES §1).
CivilDate civilDateIn(DateTime instant, tz.Location location) {
  final local = tz.TZDateTime.from(instant, location);
  return CivilDate(local.year, local.month, local.day);
}

/// "Today" in the user's timezone, not the device's and not UTC.
class UserClock {
  UserClock(String timezone, {DateTime Function()? now})
    : location = _locationOrDefault(timezone),
      _now = now ?? DateTime.now;

  final tz.Location location;
  final DateTime Function() _now;

  CivilDate today() => civilDateIn(_now(), location);

  /// The current instant as a wall-clock time in the user's timezone.
  tz.TZDateTime now() => tz.TZDateTime.from(_now(), location);

  static tz.Location _locationOrDefault(String name) {
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return tz.getLocation(defaultTimezone);
    }
  }
}

/// The timezone saved in `user_settings`.
final userTimezoneProvider = StreamProvider<String>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .userSettingsDao
      .watchActive()
      .map((rows) => rows.isEmpty ? defaultTimezone : rows.first.timezone),
);

/// The clock every screen and repository uses for "today". It is replaced
/// whenever the timezone setting changes.
final userClockProvider = Provider<UserClock>(
  (ref) => UserClock(ref.watch(userTimezoneProvider).value ?? defaultTimezone),
);
