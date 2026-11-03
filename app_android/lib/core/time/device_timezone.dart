/// Best-effort IANA timezone for registration. The app is Indonesia-first, so
/// the device's UTC offset is mapped to the matching Indonesian zone and
/// anything else falls back to `Asia/Jakarta`. The user can change the
/// timezone later in preferences (Fase 2).
String guessIanaTimezone([Duration? offset]) {
  final current = offset ?? DateTime.now().timeZoneOffset;
  switch (current.inHours) {
    case 8:
      return 'Asia/Makassar';
    case 9:
      return 'Asia/Jayapura';
    default:
      return 'Asia/Jakarta';
  }
}
