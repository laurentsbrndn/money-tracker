import '../time/civil_date.dart';
import 'period.dart';

/// Plain value types for the formulas of BUSINESS_RULES. They are not Drift
/// rows, so the rules stay pure; IDs are opaque strings and rows that are
/// soft-deleted are flagged with `deleted` and never count.

enum AccountType {
  bank('bank'),
  eWallet('e_wallet'),
  cash('cash'),
  savings('savings');

  const AccountType(this.value);

  final String value;

  static AccountType fromValue(String value) =>
      values.firstWhere((e) => e.value == value);
}

enum TransactionType {
  income('income'),
  expense('expense'),
  transfer('transfer'),
  adjustment('adjustment');

  const TransactionType(this.value);

  final String value;

  static TransactionType fromValue(String value) =>
      values.firstWhere((e) => e.value == value);
}

enum TransactionStatus {
  posted('posted'),
  pendingConfirmation('pending_confirmation');

  const TransactionStatus(this.value);

  final String value;

  static TransactionStatus fromValue(String value) =>
      values.firstWhere((e) => e.value == value);
}

enum Allocation {
  needs('needs'),
  wants('wants'),
  savings('savings');

  const Allocation(this.value);

  final String value;

  static Allocation fromValue(String value) =>
      values.firstWhere((e) => e.value == value);
}

class Account {
  const Account({
    required this.id,
    required this.type,
    required this.openingBalance,
    required this.openingDate,
    required this.includeInTotal,
    required this.deleted,
  });

  final String id;
  final AccountType type;
  final int openingBalance;
  final CivilDate openingDate;
  final bool includeInTotal;
  final bool deleted;
}

/// [toAccountId] is null unless [type] is transfer; [allocation] is null
/// unless [type] is expense; [categoryId] is null for transfers and
/// adjustments; [amount] is signed for adjustments.
class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.status,
    required this.date,
    required this.amount,
    required this.accountId,
    required this.deleted,
    this.toAccountId,
    this.allocation,
    this.categoryId,
    this.source,
  });

  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final CivilDate date;
  final int amount;
  final String accountId;
  final String? toAccountId;
  final Allocation? allocation;

  /// Only set for expenses and income; used by the per-category breakdown.
  final String? categoryId;

  /// "Dari mana" of an income; used by the per-source report.
  final String? source;
  final bool deleted;
}

/// The real balance a user observed on a date.
class BalanceSnapshot {
  const BalanceSnapshot({
    required this.accountId,
    required this.date,
    required this.amount,
    required this.updatedAt,
    required this.deleted,
  });

  final String accountId;
  final CivilDate date;
  final int amount;
  final DateTime updatedAt;
  final bool deleted;
}

/// The needs/wants/savings split effective from a month.
class BudgetGoal {
  const BudgetGoal({
    required this.effectiveMonth,
    required this.needsPct,
    required this.wantsPct,
    required this.savingsPct,
    required this.deleted,
    this.plannedIncome,
  });

  final YearMonth effectiveMonth;
  final int needsPct;
  final int wantsPct;
  final int savingsPct;
  final int? plannedIncome;
  final bool deleted;
}
