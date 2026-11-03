import '../../../core/time/civil_date.dart';

/// Filters of the history list (APP_FLOWS Flow 4): type, account, category,
/// allocation, date range, and search text (note and source).
class TransactionFilter {
  const TransactionFilter({
    this.type,
    this.accountId,
    this.categoryId,
    this.allocation,
    this.from,
    this.to,
    this.query = '',
  });

  final String? type;
  final String? accountId;
  final String? categoryId;
  final String? allocation;
  final CivilDate? from;
  final CivilDate? to;
  final String query;

  /// Number of filters set (search text not counted), for the badge.
  int get activeCount => [
    type,
    accountId,
    categoryId,
    allocation,
    from,
    to,
  ].where((value) => value != null).length;

  bool get isEmpty => activeCount == 0 && query.trim().isEmpty;

  TransactionFilter copyWith({
    String? Function()? type,
    String? Function()? accountId,
    String? Function()? categoryId,
    String? Function()? allocation,
    CivilDate? Function()? from,
    CivilDate? Function()? to,
    String? query,
  }) => TransactionFilter(
    type: type != null ? type() : this.type,
    accountId: accountId != null ? accountId() : this.accountId,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    allocation: allocation != null ? allocation() : this.allocation,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    query: query ?? this.query,
  );
}
