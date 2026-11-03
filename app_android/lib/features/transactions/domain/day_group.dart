import '../../../core/database/app_database.dart';
import '../../../core/database/mappers/row_mappers.dart';
import '../../../core/domain_rules/balance.dart';
import '../../../core/domain_rules/types.dart';
import '../../../core/time/civil_date.dart';

/// The transactions of one calendar day with the day's net amount
/// (income minus expense of transactions that count, BUSINESS_RULES §3).
class DayGroup {
  const DayGroup({
    required this.date,
    required this.transactions,
    required this.net,
  });

  final CivilDate date;
  final List<TransactionRow> transactions;
  final int net;
}

/// Groups [rows] (already newest first) by `transaction_date`.
List<DayGroup> groupByDay(List<TransactionRow> rows, CivilDate asOf) {
  final groups = <DayGroup>[];
  var currentDate = rows.isEmpty ? null : rows.first.transactionDate;
  var bucket = <TransactionRow>[];

  void flush() {
    if (currentDate == null || bucket.isEmpty) {
      return;
    }
    var net = 0;
    for (final row in bucket) {
      final tx = row.toDomain();
      if (!counts(tx, asOf)) {
        continue;
      }
      switch (tx.type) {
        case TransactionType.income:
          net += tx.amount;
        case TransactionType.expense:
          net -= tx.amount;
        case TransactionType.transfer:
        case TransactionType.adjustment:
          break;
      }
    }
    groups.add(DayGroup(date: currentDate, transactions: bucket, net: net));
  }

  for (final row in rows) {
    if (row.transactionDate != currentDate) {
      flush();
      currentDate = row.transactionDate;
      bucket = [];
    }
    bucket.add(row);
  }
  flush();
  return groups;
}
