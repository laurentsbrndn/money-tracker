/// Splits [total] rows into pages: the first page holds [firstPage] rows (it
/// also carries the summary), the others [perPage]. Returns `[start, end)`
/// index pairs. An empty list yields one empty page so the summary still
/// prints.
List<(int, int)> paginateRows(int total, int firstPage, int perPage) {
  final pages = <(int, int)>[];
  var start = 0;
  var size = firstPage;
  do {
    final end = start + size > total ? total : start + size;
    pages.add((start, end));
    start = end;
    size = perPage;
  } while (start < total);
  return pages;
}

/// Text for the standard PDF fonts, which only cover Latin-1: other
/// characters become `?`, line breaks become spaces, and [maxLength] cuts
/// long notes with `...`.
String pdfSafeText(String value, {int maxLength = 60}) {
  final buffer = StringBuffer();
  for (final unit in value.runes) {
    if (unit == 0x0A || unit == 0x0D || unit == 0x09) {
      buffer.write(' ');
    } else if (unit < 0x20 || unit > 0xFF) {
      buffer.write('?');
    } else {
      buffer.writeCharCode(unit);
    }
  }
  final text = buffer.toString();
  return text.length > maxLength
      ? '${text.substring(0, maxLength - 3)}...'
      : text;
}
