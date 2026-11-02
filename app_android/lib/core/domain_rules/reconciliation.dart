import '../time/civil_date.dart';
import 'balance.dart';
import 'types.dart';

/// A snapshot taken exactly 7 days before `asOf` is not stale yet
/// (BUSINESS_RULES §4.4).
const int staleAfterDays = 7;

enum ReconciliationStatus { matched, mismatch, stale }

/// One account's latest snapshot compared with what the transactions say.
///
/// [expectedBalance] is evaluated at `asOf`; [diff] at the snapshot date. An
/// account with no snapshot is reported stale with [hasSnapshot] false, zero
/// amounts, and zero diff.
class AccountReconciliation {
  const AccountReconciliation({
    required this.accountId,
    required this.accountType,
    required this.expectedBalance,
    required this.hasSnapshot,
    required this.latestSnapshotAmount,
    required this.diff,
    required this.status,
    this.latestSnapshotDate,
  });

  final String accountId;
  final AccountType accountType;
  final int expectedBalance;
  final bool hasSnapshot;
  final int latestSnapshotAmount;
  final CivilDate? latestSnapshotDate;
  final int diff;
  final ReconciliationStatus status;
}

/// Account sums of BUSINESS_RULES §4.2-§4.4.
class Totals {
  const Totals({
    required this.expectedTotal,
    required this.actualAccounts,
    required this.actualCash,
    required this.actualTotal,
    required this.diffTotal,
  });

  final int expectedTotal;

  /// Bank, e_wallet, and savings.
  final int actualAccounts;
  final int actualCash;
  final int actualTotal;
  final int diffTotal;
}

class Reconciliation {
  const Reconciliation({required this.accounts, required this.totals});

  final List<AccountReconciliation> accounts;
  final Totals totals;
}

/// The account's newest snapshot on or before [asOf]: the largest date, then
/// the largest `updatedAt`. Deleted snapshots are ignored.
BalanceSnapshot? latestSnapshot(
  List<BalanceSnapshot> snapshots,
  String accountId,
  CivilDate asOf,
) {
  BalanceSnapshot? best;
  for (final snapshot in snapshots) {
    if (snapshot.deleted ||
        snapshot.accountId != accountId ||
        snapshot.date.isAfter(asOf)) {
      continue;
    }
    if (best == null ||
        snapshot.date.isAfter(best.date) ||
        (snapshot.date == best.date &&
            snapshot.updatedAt.isAfter(best.updatedAt))) {
      best = snapshot;
    }
  }
  return best;
}

/// BUSINESS_RULES §4.2-§4.4 for every account that is part of the total, in
/// input order.
Reconciliation reconcile(
  List<Account> accounts,
  List<Transaction> txs,
  List<BalanceSnapshot> snapshots,
  CivilDate asOf,
) {
  final results = <AccountReconciliation>[];
  var expectedSum = 0;
  var actualAccounts = 0;
  var actualCash = 0;
  var diffSum = 0;

  for (final account in accounts) {
    if (!inTotal(account)) {
      continue;
    }
    final expected = expectedBalance(account, txs, asOf);
    final snapshot = latestSnapshot(snapshots, account.id, asOf);

    var diff = 0;
    var status = ReconciliationStatus.stale;
    if (snapshot != null) {
      diff = snapshot.amount - expectedBalance(account, txs, snapshot.date);
      if (asOf.daysSince(snapshot.date) > staleAfterDays) {
        status = ReconciliationStatus.stale;
      } else if (diff == 0) {
        status = ReconciliationStatus.matched;
      } else {
        status = ReconciliationStatus.mismatch;
      }
      if (account.type == AccountType.cash) {
        actualCash += snapshot.amount;
      } else {
        actualAccounts += snapshot.amount;
      }
    }

    expectedSum += expected;
    diffSum += diff;
    results.add(
      AccountReconciliation(
        accountId: account.id,
        accountType: account.type,
        expectedBalance: expected,
        hasSnapshot: snapshot != null,
        latestSnapshotAmount: snapshot?.amount ?? 0,
        latestSnapshotDate: snapshot?.date,
        diff: diff,
        status: status,
      ),
    );
  }

  return Reconciliation(
    accounts: results,
    totals: Totals(
      expectedTotal: expectedSum,
      actualAccounts: actualAccounts,
      actualCash: actualCash,
      actualTotal: actualAccounts + actualCash,
      diffTotal: diffSum,
    ),
  );
}
