import '../time/civil_date.dart';
import 'balance.dart';
import 'budget.dart';
import 'period.dart';
import 'types.dart';

/// The last day a month's figures cover: its last day, or [today] while the
/// month is not over (BUSINESS_RULES §3, API.md §5). Months after the current
/// one are read as of today, so they stay empty.
CivilDate reportAsOf(YearMonth month, CivilDate today) =>
    month.last.isBefore(today) ? month.last : today;

/// A sum for one key of a breakdown ([key] is null for "no category" or
/// "no source").
class KeyedAmount {
  const KeyedAmount({required this.key, required this.amount});

  final String? key;
  final int amount;
}

/// BUSINESS_RULES §4.6: the month's expenses per category, largest first.
List<KeyedAmount> expenseByCategory(
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
) => _sumBy(txs, month, asOf, TransactionType.expense, (tx) => tx.categoryId);

/// BUSINESS_RULES §4.6: the month's income per category, largest first.
List<KeyedAmount> incomeByCategory(
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
) => _sumBy(txs, month, asOf, TransactionType.income, (tx) => tx.categoryId);

/// BUSINESS_RULES §4.6: the month's income per `source`, largest first. An
/// income without a source (or a blank one) is grouped under null; sources
/// that differ only in case or surrounding spaces are one.
List<KeyedAmount> incomeBySource(
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
) {
  final totals = <String, int>{};
  final labels = <String, String>{};
  var none = 0;
  for (final tx in txs) {
    if (!counts(tx, asOf) ||
        !month.contains(tx.date) ||
        tx.type != TransactionType.income) {
      continue;
    }
    final label = tx.source?.trim() ?? '';
    if (label.isEmpty) {
      none += tx.amount;
      continue;
    }
    final key = label.toLowerCase();
    labels.putIfAbsent(key, () => label);
    totals[key] = (totals[key] ?? 0) + tx.amount;
  }
  return _sorted([
    for (final entry in totals.entries)
      KeyedAmount(key: labels[entry.key], amount: entry.value),
    if (none != 0) KeyedAmount(key: null, amount: none),
  ]);
}

List<KeyedAmount> _sumBy(
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
  TransactionType type,
  String? Function(Transaction) keyOf,
) {
  final totals = <String?, int>{};
  for (final tx in txs) {
    if (counts(tx, asOf) && month.contains(tx.date) && tx.type == type) {
      totals[keyOf(tx)] = (totals[keyOf(tx)] ?? 0) + tx.amount;
    }
  }
  return _sorted([
    for (final entry in totals.entries)
      KeyedAmount(key: entry.key, amount: entry.value),
  ]);
}

/// Largest amount first; ties by key so the order is stable.
List<KeyedAmount> _sorted(List<KeyedAmount> items) => items
  ..sort((a, b) {
    final byAmount = b.amount.compareTo(a.amount);
    return byAmount != 0 ? byAmount : (a.key ?? '').compareTo(b.key ?? '');
  });

/// BUSINESS_RULES §4.6: the signed sum of the month's adjustments, the
/// differences the user did not record.
int unrecordedDifference(
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
) {
  var total = 0;
  for (final tx in txs) {
    if (counts(tx, asOf) &&
        month.contains(tx.date) &&
        tx.type == TransactionType.adjustment) {
      total += tx.amount;
    }
  }
  return total;
}

/// One month of the trend report (BUSINESS_RULES §4.6).
class TrendMonth {
  const TrendMonth({
    required this.month,
    required this.income,
    required this.expense,
    required this.surplus,
    required this.savings,
    required this.adjustments,
  });

  final YearMonth month;
  final int income;
  final int expense;
  final int surplus;

  /// `savings(M)` of BUSINESS_RULES §4.5.
  final int savings;

  /// Signed sum of the month's adjustments.
  final int adjustments;
}

/// BUSINESS_RULES §4.6: income, expense, surplus, savings and unrecorded
/// differences of the [months] months that end with [last], oldest first.
/// Every month is figured as of its own last day (or [today] for the current
/// month), like the server's `GET /v1/reports/trend`.
List<TrendMonth> trendReport(
  List<Account> accounts,
  List<Transaction> txs,
  List<BudgetGoal> goals,
  YearMonth last,
  int months,
  CivilDate today,
) {
  final result = <TrendMonth>[];
  for (var back = months - 1; back >= 0; back--) {
    final month = last.addMonths(-back);
    final asOf = reportAsOf(month, today);
    final summary = computeMonthlySummary(accounts, txs, month, asOf);
    final budget = computeBudget(
      accounts,
      txs,
      effectiveGoal(goals, month),
      month,
      asOf,
    );
    result.add(
      TrendMonth(
        month: month,
        income: summary.income,
        expense: summary.expense,
        surplus: summary.surplus,
        savings: budget.savings.actual,
        adjustments: unrecordedDifference(txs, month, asOf),
      ),
    );
  }
  return result;
}

/// One line of the comparison between a month and the one before it.
class MonthComparisonLine {
  const MonthComparisonLine({
    required this.key,
    required this.current,
    required this.previous,
  });

  /// A category id; null is "no category".
  final String? key;
  final int current;
  final int previous;

  int get change => current - previous;
}

/// This month against the month before (BUSINESS_RULES §4.6 "perbandingan").
class MonthComparison {
  const MonthComparison({
    required this.month,
    required this.current,
    required this.previous,
    required this.expenseByCategory,
  });

  final YearMonth month;
  final TrendMonth current;
  final TrendMonth previous;

  /// Per expense category, largest current amount first.
  final List<MonthComparisonLine> expenseByCategory;
}

/// The figures of [month] next to those of the month before it. The previous
/// month is figured as of its last day, the current one as of [today].
MonthComparison compareMonths(
  List<Account> accounts,
  List<Transaction> txs,
  List<BudgetGoal> goals,
  YearMonth month,
  CivilDate today,
) {
  final pair = trendReport(accounts, txs, goals, month, 2, today);
  final asOfNow = reportAsOf(month, today);
  final asOfBefore = reportAsOf(month.addMonths(-1), today);
  final now = {
    for (final item in expenseByCategory(txs, month, asOfNow))
      item.key: item.amount,
  };
  final before = {
    for (final item in expenseByCategory(txs, month.addMonths(-1), asOfBefore))
      item.key: item.amount,
  };
  final lines =
      [
        for (final key in {...now.keys, ...before.keys})
          MonthComparisonLine(
            key: key,
            current: now[key] ?? 0,
            previous: before[key] ?? 0,
          ),
      ]..sort((a, b) {
        final byCurrent = b.current.compareTo(a.current);
        if (byCurrent != 0) {
          return byCurrent;
        }
        final byPrevious = b.previous.compareTo(a.previous);
        return byPrevious != 0
            ? byPrevious
            : (a.key ?? '').compareTo(b.key ?? '');
      });
  return MonthComparison(
    month: month,
    current: pair[1],
    previous: pair[0],
    expenseByCategory: lines,
  );
}
