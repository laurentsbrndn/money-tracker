/// How the CSV column separator is chosen (the export dialog offers all three).
enum CsvDelimiterChoice { auto, comma, semicolon }

/// The one place the separator rule lives; iOS must use the same rule
/// (FRONTEND_FLUTTER.md §4.7). A locale whose decimal separator is a comma
/// (id-ID, most of Europe) gets `;` because Excel there reads `,` as the
/// decimal mark; a locale with a decimal point (en-US) gets `,`.
const String _semicolonLocaleDecimalSeparator = ',';

String resolveCsvDelimiter(
  CsvDelimiterChoice choice,
  String deviceDecimalSeparator,
) => switch (choice) {
  CsvDelimiterChoice.comma => ',',
  CsvDelimiterChoice.semicolon => ';',
  CsvDelimiterChoice.auto =>
    deviceDecimalSeparator == _semicolonLocaleDecimalSeparator ? ';' : ',',
};
