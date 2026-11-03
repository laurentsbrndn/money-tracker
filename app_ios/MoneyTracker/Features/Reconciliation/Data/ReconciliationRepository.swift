import Foundation
import GRDB

/// Writes the balance snapshots and adjustments of the reconcile flow (APP_FLOWS Flow 5). Every
/// write goes through the `OutboxWriter`.
struct ReconciliationRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter

    private let ids = IDGenerator()

    init(database: AppDatabase, writer: OutboxWriter) {
        self.database = database
        self.writer = writer
    }

    private static func requireAccount(_ db: Database, _ id: String) throws -> AccountRecord {
        guard let account = try db.account(id: id), account.deletedAt == nil else {
            throw ValidationError.accountRequired
        }
        return account
    }

    /// Saves the observed real balances as snapshots dated today, all in one transaction. A
    /// balance equal to the account's snapshot of today is not saved twice. Returns the ids of
    /// the accounts that now have a snapshot dated today.
    func saveSnapshots(_ balances: [String: Int64]) async throws -> [String] {
        let today = UserClock.today()
        let newIDs = Dictionary(uniqueKeysWithValues: balances.keys.map { ($0, ids.newID()) })
        return try await writer.write { tx in
            var saved: [String] = []
            for (accountId, amount) in balances.sorted(by: { $0.key < $1.key }) {
                let account = try Self.requireAccount(tx.db, accountId)
                if amount.magnitude > UInt64(maxAmount) { throw ValidationError.amountRange }
                if today < account.openingDate { throw ValidationError.snapshotDateInvalid }
                let latestOfDay = try tx.db.snapshots(accountId: accountId)
                    .filter { $0.snapshotDate == today }
                    .max { $0.updatedAt < $1.updatedAt }
                if latestOfDay?.amount != amount {
                    try tx.upsert(
                        BalanceSnapshotRecord(
                            id: newIDs[accountId] ?? UUID().uuidString.lowercased(),
                            createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                            serverVersion: nil, syncStatus: "pending", syncError: nil,
                            accountId: accountId, snapshotDate: today, amount: amount, note: nil))
                }
                saved.append(accountId)
            }
            return saved
        }
    }

    /// Records a signed `adjustment` for the difference between the observed and the expected
    /// balance (BUSINESS_RULES §6: only account, amount, date, and note are set).
    @discardableResult
    func createAdjustment(accountId: String, amount: Int64, date: CivilDate, note: String)
        async throws -> String
    {
        if amount == 0 { throw ValidationError.adjustmentZero }
        if amount.magnitude > UInt64(maxAmount) { throw ValidationError.amountRange }
        let id = ids.newID()
        try await writer.write { tx in
            let account = try Self.requireAccount(tx.db, accountId)
            if date < account.openingDate { throw ValidationError.dateBeforeOpening }
            try tx.upsert(
                TransactionRecord(
                    id: id, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                    serverVersion: nil, syncStatus: "pending", syncError: nil,
                    type: "adjustment", status: "posted", transactionDate: date, amount: amount,
                    currency: "IDR", accountId: accountId, toAccountId: nil, categoryId: nil,
                    allocation: nil, source: nil, note: note, linkedTransactionId: nil,
                    recurringRuleId: nil))
        }
        return id
    }

    /// Re-reads everything now and books an adjustment for the account's current difference. A
    /// double tap, or a transaction added meanwhile, cannot book a stale amount; a difference of 0
    /// does nothing. Returns the booked amount (0 when nothing was booked).
    func adjustCurrentDifference(accountId: String, note: String) async throws -> Int64 {
        let today = UserClock.today()
        let result = try await database.pool.read { db in
            DomainRules.reconcile(
                accounts: try db.liveAccounts().map(\.domain),
                transactions: try db.allTransactions().map(\.domain),
                snapshots: try db.allSnapshots().map(\.domain), asOf: today)
        }
        guard let entry = result.accounts.first(where: { $0.accountID == accountId }),
            let date = entry.latestSnapshotDate, entry.diff != 0
        else { return 0 }
        try await createAdjustment(accountId: accountId, amount: entry.diff, date: date, note: note)
        return entry.diff
    }
}
