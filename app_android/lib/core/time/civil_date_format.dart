import '../domain_rules/period.dart';
import 'civil_date.dart';

const List<String> _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> _weekdayNames = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String monthName(int month) => _monthNames[month - 1];

/// ISO weekday (Monday = 1 ... Sunday = 7) in Indonesian.
String weekdayName(int isoWeekday) => _weekdayNames[isoWeekday - 1];

/// `2 Nov 2026`.
String formatCivilDateShort(CivilDate date) =>
    '${date.day} ${monthName(date.month).substring(0, 3)} ${date.year}';

/// `Senin, 2 November 2026`.
String formatCivilDateLong(CivilDate date) =>
    '${_weekdayNames[date.weekday - 1]}, ${date.day} ${monthName(date.month)} ${date.year}';

/// `November 2026`.
String formatYearMonth(YearMonth month) =>
    '${monthName(month.month)} ${month.year}';
