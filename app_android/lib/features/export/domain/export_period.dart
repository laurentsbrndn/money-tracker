import '../../../core/time/civil_date.dart';

/// The shortcuts of the export period picker.
enum ExportPreset { thisMonth, lastMonth, last3Months, thisYear, allData }

/// A closed range of civil dates; both null means all data.
class ExportPeriod {
  const ExportPeriod({this.from, this.to});

  final CivilDate? from;
  final CivilDate? to;

  bool get isAll => from == null && to == null;

  /// "Tanggal awal tidak boleh setelah tanggal akhir."
  bool get isValid =>
      isAll || (from != null && to != null && !from!.isAfter(to!));
}

/// The period of [preset] relative to [today] (the user's timezone).
/// "3 bulan terakhir" is the current month and the two before it, the same
/// window the free plan can view (BUSINESS_RULES §7).
ExportPeriod periodForPreset(ExportPreset preset, CivilDate today) {
  switch (preset) {
    case ExportPreset.thisMonth:
      return ExportPeriod(from: today.firstOfMonth, to: today.lastOfMonth);
    case ExportPreset.lastMonth:
      final last = today.firstOfMonth.addDays(-1);
      return ExportPeriod(from: last.firstOfMonth, to: last.lastOfMonth);
    case ExportPreset.last3Months:
      var first = today.firstOfMonth;
      for (var i = 0; i < 2; i++) {
        first = first.addDays(-1).firstOfMonth;
      }
      return ExportPeriod(from: first, to: today.lastOfMonth);
    case ExportPreset.thisYear:
      return ExportPeriod(
        from: CivilDate(today.year, 1, 1),
        to: CivilDate(today.year, 12, 31),
      );
    case ExportPreset.allData:
      return const ExportPeriod();
  }
}
