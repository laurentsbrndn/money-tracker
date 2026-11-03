/// Wire timestamps (SYNC_PROTOCOL §4): RFC 3339 UTC with exactly three
/// millisecond digits and a `Z` suffix, truncated (never rounded).
String formatTimestamp(DateTime value) {
  final utc = value.toUtc();
  String pad(int n, int width) => n.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}-${pad(utc.month, 2)}-${pad(utc.day, 2)}'
      'T${pad(utc.hour, 2)}:${pad(utc.minute, 2)}:${pad(utc.second, 2)}'
      '.${pad(utc.millisecond, 3)}Z';
}

/// Parses an RFC 3339 timestamp to UTC, truncated to milliseconds.
DateTime parseTimestamp(String value) =>
    truncateToMillis(DateTime.parse(value));

DateTime truncateToMillis(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    );
