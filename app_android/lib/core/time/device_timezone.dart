import 'package:flutter_timezone/flutter_timezone.dart';

import 'user_clock.dart';

/// The device's IANA timezone, used as the initial `user_settings.timezone`
/// when registering (APP_FLOWS Flow 12 lets the user change it later). Falls
/// back to [defaultTimezone] when the platform returns a name that the bundled
/// timezone database does not know.
Future<String> detectDeviceTimezone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    if (isValidTimezone(info.identifier)) {
      return info.identifier;
    }
  } on Object {
    // Fall through to the default.
  }
  return defaultTimezone;
}
