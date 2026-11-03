import '../../../core/time/civil_date.dart';

/// `money-tracker_2026-11-01_2026-11-30.csv`: the period is in the name. For
/// an export of all data the caller passes the dates of the first and last
/// transaction.
String exportFileName(CivilDate from, CivilDate to, String extension) =>
    'money-tracker_${from}_$to.$extension';

/// Prefix shared by every file the export writes, so leftovers can be found.
const String exportFilePrefix = 'money-tracker_';
