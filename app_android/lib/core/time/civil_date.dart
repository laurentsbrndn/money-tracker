/// A calendar date (`YYYY-MM-DD`) without time or timezone.
class CivilDate implements Comparable<CivilDate> {
  const CivilDate(this.year, this.month, this.day);

  /// Parses `YYYY-MM-DD`. Throws [FormatException] on malformed or impossible dates.
  factory CivilDate.parse(String value) {
    final match = _pattern.firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid civil date', value);
    }
    final date = CivilDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (date.month < 1 ||
        date.month > 12 ||
        date.day < 1 ||
        date.day > daysInMonth(date.year, date.month)) {
      throw FormatException('Invalid civil date', value);
    }
    return date;
  }

  /// Takes the calendar fields of [dateTime] as-is (no timezone conversion).
  factory CivilDate.fromDateTime(DateTime dateTime) =>
      CivilDate(dateTime.year, dateTime.month, dateTime.day);

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  final int year;
  final int month;
  final int day;

  static bool isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) {
    const lengths = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    if (month == 2 && isLeapYear(year)) {
      return 29;
    }
    return lengths[month - 1];
  }

  /// ISO weekday: Monday = 1 ... Sunday = 7.
  int get weekday => _asUtc.weekday;

  CivilDate get firstOfMonth => CivilDate(year, month, 1);

  CivilDate get lastOfMonth => CivilDate(year, month, daysInMonth(year, month));

  CivilDate addDays(int days) =>
      CivilDate.fromDateTime(_asUtc.add(Duration(days: days)));

  /// Whole days from [other] to this date (positive when this is later).
  int daysSince(CivilDate other) => _asUtc.difference(other._asUtc).inDays;

  DateTime get _asUtc => DateTime.utc(year, month, day);

  bool isBefore(CivilDate other) => compareTo(other) < 0;

  bool isAfter(CivilDate other) => compareTo(other) > 0;

  @override
  int compareTo(CivilDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CivilDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}
