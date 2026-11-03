import Foundation

enum ReconciliationStatus: String, Sendable {
    case matched
    case mismatch
    case stale
}

/// One account's latest snapshot compared with what the transactions say.
///
/// `expectedBalance` is evaluated at `asOf`; `diff` is evaluated at the snapshot date. An
/// account with no snapshot (every account should have one, §2.3) is reported `.stale` with
/// `hasSnapshot` false, zero amounts, and zero diff.
struct AccountReconciliation: Sendable, Equatable {
    var accountID: String
    var accountType: AccountType
    var expectedBalance: Int64
    var hasSnapshot: Bool
    var latestSnapshotAmount: Int64
    var latestSnapshotDate: CivilDate?
    var diff: Int64
    var status: ReconciliationStatus
}

/// Account sums of §4.2–§4.4.
struct ReconciliationTotals: Sendable, Equatable {
    var expectedTotal: Int64 = 0
    /// bank, e_wallet, savings
    var actualAccounts: Int64 = 0
    var actualCash: Int64 = 0
    var actualTotal: Int64 = 0
    var diffTotal: Int64 = 0
}

struct Reconciliation: Sendable, Equatable {
    var accounts: [AccountReconciliation]
    var totals: ReconciliationTotals
}

extension DomainRules {
    /// A snapshot taken exactly 7 days before `asOf` is not stale yet (§4.4).
    static let staleAfterDays = 7

    /// The account's newest snapshot on or before `asOf`: the largest date, then the largest
    /// `updatedAt`. Deleted snapshots are ignored.
    static func latestSnapshot(
        _ snapshots: [BalanceSnapshot], accountID: String, asOf: CivilDate
    ) -> BalanceSnapshot? {
        var best: BalanceSnapshot?
        for s in snapshots where !s.isDeleted && s.accountID == accountID && s.date <= asOf {
            if let current = best {
                if s.date > current.date
                    || (s.date == current.date && s.updatedAt > current.updatedAt)
                {
                    best = s
                }
            } else {
                best = s
            }
        }
        return best
    }

    /// §4.2–§4.4 for every account that is part of the total, in input order.
    static func reconcile(
        accounts: [Account], transactions: [Transaction], snapshots: [BalanceSnapshot],
        asOf: CivilDate
    ) -> Reconciliation {
        var totals = ReconciliationTotals()
        var results: [AccountReconciliation] = []
        for account in accounts where isInTotal(account) {
            var rec = AccountReconciliation(
                accountID: account.id,
                accountType: account.type,
                expectedBalance: expectedBalance(
                    account: account, transactions: transactions, on: asOf),
                hasSnapshot: false,
                latestSnapshotAmount: 0,
                latestSnapshotDate: nil,
                diff: 0,
                status: .stale)

            if let snap = latestSnapshot(snapshots, accountID: account.id, asOf: asOf) {
                rec.hasSnapshot = true
                rec.latestSnapshotAmount = snap.amount
                rec.latestSnapshotDate = snap.date
                rec.diff =
                    snap.amount
                    - expectedBalance(account: account, transactions: transactions, on: snap.date)
                if asOf.days(since: snap.date) > staleAfterDays {
                    rec.status = .stale
                } else if rec.diff == 0 {
                    rec.status = .matched
                } else {
                    rec.status = .mismatch
                }

                if account.type == .cash {
                    totals.actualCash += snap.amount
                } else {
                    totals.actualAccounts += snap.amount
                }
            }

            totals.expectedTotal += rec.expectedBalance
            totals.diffTotal += rec.diff
            results.append(rec)
        }
        totals.actualTotal = totals.actualAccounts + totals.actualCash
        return Reconciliation(accounts: results, totals: totals)
    }
}
