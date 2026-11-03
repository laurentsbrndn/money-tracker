/// The reports of APP_FLOWS Flow 8.
enum ReportKind {
  /// Expenses of a month per category.
  category,

  /// Income of a month per source.
  source,

  /// Income, expense and savings over 6 or 12 months.
  trend,

  /// A month against the month before.
  comparison,

  /// The differences the user did not record, per month.
  unrecorded;

  /// Premium only (BUSINESS_RULES §7): trend, comparison, and unrecorded
  /// differences.
  bool get premiumOnly => switch (this) {
    category || source => false,
    trend || comparison || unrecorded => true,
  };

  /// The report is about one month (the month selector is shown).
  bool get usesMonth => switch (this) {
    category || source || comparison => true,
    trend || unrecorded => false,
  };

  /// The report spans several months (6 or 12 can be chosen).
  bool get usesRange => !usesMonth;
}
