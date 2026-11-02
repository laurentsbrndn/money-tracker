import '../time/civil_date.dart';

/// A calendar month (`YYYY-MM`), the reporting period.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  /// Reads a strict `YYYY-MM` string. Throws [FormatException] otherwise.
  factory YearMonth.parse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) {
      throw FormatException('Invalid month', value);
    }
    return YearMonth(int.parse(match.group(1)!), month);
  }

  /// The month that contains [date].
  factory YearMonth.of(CivilDate date) => YearMonth(date.year, date.month);

  final int year;

  /// 1-12.
  final int month;

  CivilDate get first => CivilDate(year, month, 1);

  CivilDate get last => first.lastOfMonth;

  bool contains(CivilDate date) => date.year == year && date.month == month;

  /// The month [n] months after this one ([n] may be negative).
  YearMonth addMonths(int n) {
    final index = year * 12 + month - 1 + n;
    return YearMonth(index ~/ 12, index % 12 + 1);
  }

  @override
  int compareTo(YearMonth other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    return month.compareTo(other.month);
  }

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
}
