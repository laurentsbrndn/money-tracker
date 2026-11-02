import '../time/civil_date.dart';
import 'period.dart';
import 'types.dart';

/// Whether [tx] takes part in any formula as of [asOf] (BUSINESS_RULES §3):
/// not deleted, posted, and dated on or before [asOf].
bool counts(Transaction tx, CivilDate asOf) =>
    !tx.deleted &&
    tx.status == TransactionStatus.posted &&
    !tx.date.isAfter(asOf);

/// Whether the account is part of totals: included and not deleted.
/// Archived accounts still count.
bool inTotal(Account account) => account.includeInTotal && !account.deleted;

/// E(A, d): the opening balance plus every counted transaction of the account
/// dated within `[opening_date, d]` (BUSINESS_RULES §4.2).
int expectedBalance(Account account, List<Transaction> txs, CivilDate d) {
  var balance = account.openingBalance;
  for (final tx in txs) {
    if (!counts(tx, d) || tx.date.isBefore(account.openingDate)) {
      continue;
    }
    switch (tx.type) {
      case TransactionType.income:
      case TransactionType.adjustment:
        if (tx.accountId == account.id) {
          balance += tx.amount;
        }
      case TransactionType.expense:
        if (tx.accountId == account.id) {
          balance -= tx.amount;
        }
      case TransactionType.transfer:
        if (tx.accountId == account.id) {
          balance -= tx.amount;
        }
        if (tx.toAccountId == account.id) {
          balance += tx.amount;
        }
    }
  }
  return balance;
}

/// Sum of E(A, d) over the accounts that are part of the total.
int expectedTotal(List<Account> accounts, List<Transaction> txs, CivilDate d) {
  var total = 0;
  for (final account in accounts) {
    if (inTotal(account)) {
      total += expectedBalance(account, txs, d);
    }
  }
  return total;
}

/// The income/expense summary of one month.
class MonthlySummary {
  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.surplus,
    required this.openingTotal,
  });

  final int income;
  final int expense;
  final int surplus;
  final int openingTotal;
}

/// BUSINESS_RULES §4.1. Transfers and adjustments are neither income nor
/// expense. `openingTotal` is the expected total on the last day of the
/// previous month.
MonthlySummary computeMonthlySummary(
  List<Account> accounts,
  List<Transaction> txs,
  YearMonth month,
  CivilDate asOf,
) {
  var income = 0;
  var expense = 0;
  for (final tx in txs) {
    if (!counts(tx, asOf) || !month.contains(tx.date)) {
      continue;
    }
    switch (tx.type) {
      case TransactionType.income:
        income += tx.amount;
      case TransactionType.expense:
        expense += tx.amount;
      case TransactionType.transfer:
      case TransactionType.adjustment:
        break;
    }
  }
  return MonthlySummary(
    income: income,
    expense: expense,
    surplus: income - expense,
    openingTotal: expectedTotal(accounts, txs, month.addMonths(-1).last),
  );
}
