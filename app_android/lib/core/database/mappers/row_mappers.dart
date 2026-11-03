import '../../domain_rules/period.dart';
import '../../domain_rules/types.dart';
import '../app_database.dart';

/// Drift rows → the plain types of `core/domain_rules` (kept free of Drift so
/// the formulas stay pure).
extension AccountRowDomain on AccountRow {
  Account toDomain() => Account(
    id: id,
    type: AccountType.fromValue(type),
    openingBalance: openingBalance,
    openingDate: openingDate,
    includeInTotal: includeInTotal,
    deleted: deletedAt != null,
  );
}

extension TransactionRowDomain on TransactionRow {
  Transaction toDomain() => Transaction(
    id: id,
    type: TransactionType.fromValue(type),
    status: TransactionStatus.fromValue(status),
    date: transactionDate,
    amount: amount,
    accountId: accountId,
    toAccountId: toAccountId,
    allocation: allocation == null ? null : Allocation.fromValue(allocation!),
    categoryId: categoryId,
    deleted: deletedAt != null,
  );
}

extension BalanceSnapshotRowDomain on BalanceSnapshotRow {
  BalanceSnapshot toDomain() => BalanceSnapshot(
    accountId: accountId,
    date: snapshotDate,
    amount: amount,
    updatedAt: updatedAt,
    deleted: deletedAt != null,
  );
}

extension BudgetGoalRowDomain on BudgetGoalRow {
  BudgetGoal toDomain() => BudgetGoal(
    effectiveMonth: YearMonth.of(effectiveMonth),
    needsPct: needsPct,
    wantsPct: wantsPct,
    savingsPct: savingsPct,
    plannedIncome: plannedIncome,
    deleted: deletedAt != null,
  );
}
