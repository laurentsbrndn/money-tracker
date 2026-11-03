import Foundation
import GRDB

/// Accounts and their opening snapshots. Reads are live streams from the local database; every
/// write goes through the `OutboxWriter` (SYNC_PROTOCOL §6).
struct AccountsRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter
    let entitlement: EntitlementStore

    private let ids = IDGenerator()

    func observeAll() -> AsyncValueObservation<[AccountRecord]> { database.observeAccounts() }

    func observe(id: String) -> AsyncValueObservation<AccountRecord?> {
        database.observeAccount(id: id)
    }

    func observeSnapshots(accountId: String) -> AsyncValueObservation<[BalanceSnapshotRecord]> {
        database.observeSnapshots(accountId: accountId)
    }

    func find(_ id: String) async throws -> AccountRecord? {
        try await database.pool.read { try $0.account(id: id) }
    }

    func hasTransactions(_ id: String) async throws -> Bool {
        try await database.pool.read { try $0.transactionCount(accountId: id) } > 0
    }

    private func validate(name: String, openingBalance: Int64, openingDate: CivilDate) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { throw ValidationError.nameRequired }
        if trimmed.count > 50 { throw ValidationError.nameTooLong }
        if openingBalance.magnitude > UInt64(maxAmount) { throw ValidationError.amountRange }
        if openingDate > UserClock.today() { throw ValidationError.openingDateFuture }
    }

    private func checkAccountLimit() async throws {
        if await entitlement.isPremium() { return }
        let open = try await database.pool.read { try $0.openAccountCount() }
        if open >= PlanLimits.maxFreeAccounts { throw PlanLimitError(kind: .accounts) }
    }

    /// Creates the account and its first balance snapshot (BUSINESS_RULES §2.3) in one
    /// transaction. Returns the new account id.
    @discardableResult
    func create(
        name: String, type: String, openingBalance: Int64, openingDate: CivilDate,
        providerKey: String? = nil, includeInTotal: Bool = true
    ) async throws -> String {
        try validate(name: name, openingBalance: openingBalance, openingDate: openingDate)
        try await checkAccountLimit()
        let id = ids.newID()
        let snapshotId = ids.newID()
        let sortOrder = try await database.pool.read { try $0.maxAccountSortOrder() } + 1
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        try await writer.write { tx in
            try tx.upsert(
                AccountRecord(
                    id: id, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                    serverVersion: nil, syncStatus: "pending", syncError: nil, name: trimmed,
                    type: type, providerKey: providerKey, currency: "IDR",
                    openingBalance: openingBalance, openingDate: openingDate,
                    includeInTotal: includeInTotal, sortOrder: sortOrder, archivedAt: nil))
            try tx.upsert(
                BalanceSnapshotRecord(
                    id: snapshotId, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                    serverVersion: nil, syncStatus: "pending", syncError: nil, accountId: id,
                    snapshotDate: openingDate, amount: openingBalance, note: nil))
        }
        return id
    }

    /// Edits the account. A changed opening balance or date also moves the account's first
    /// snapshot so the reconciliation starts from a zero diff.
    func update(
        _ existing: AccountRecord, name: String, type: String, openingBalance: Int64,
        openingDate: CivilDate, providerKey: String? = nil, includeInTotal: Bool = true
    ) async throws {
        try validate(name: name, openingBalance: openingBalance, openingDate: openingDate)
        var changed = existing
        changed.name = name.trimmingCharacters(in: .whitespaces)
        changed.type = type
        changed.providerKey = providerKey
        changed.openingBalance = openingBalance
        changed.openingDate = openingDate
        changed.includeInTotal = includeInTotal
        let openingChanged =
            openingBalance != existing.openingBalance || openingDate != existing.openingDate
        try await writer.write { [changed] tx in
            try tx.upsert(changed)
            guard openingChanged else { return }
            try Self.moveInitialSnapshot(
                tx, account: existing, openingBalance: openingBalance, openingDate: openingDate)
        }
    }

    private static func moveInitialSnapshot(
        _ tx: OutboxTx, account: AccountRecord, openingBalance: Int64, openingDate: CivilDate
    ) throws {
        for var snapshot in try tx.db.snapshots(accountId: account.id)
        where snapshot.snapshotDate == account.openingDate
            && snapshot.amount == account.openingBalance
        {
            snapshot.snapshotDate = openingDate
            snapshot.amount = openingBalance
            try tx.upsert(snapshot)
            return
        }
    }

    func setArchived(_ account: AccountRecord, archived: Bool) async throws {
        if !archived { try await checkAccountLimit() }
        try await writer.write { tx in
            var changed = account
            changed.archivedAt = archived ? tx.now : nil
            try tx.upsert(changed)
        }
    }

    /// Deletes the account; only possible while no live transaction uses it.
    func delete(_ id: String) async throws {
        if try await hasTransactions(id) { throw RecordInUseError(isAccount: true) }
        try await writer.write { tx in
            for snapshot in try tx.db.snapshots(accountId: id) {
                try tx.delete(BalanceSnapshotRecord.self, id: snapshot.id)
            }
            try tx.delete(AccountRecord.self, id: id)
        }
    }
}
