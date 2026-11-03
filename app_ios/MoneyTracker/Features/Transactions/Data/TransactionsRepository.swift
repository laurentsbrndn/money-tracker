import Foundation
import GRDB

/// Transactions: reads are live streams from the local database; every write goes through the
/// `OutboxWriter` (SYNC_PROTOCOL §6). Rules from BUSINESS_RULES §6 are checked before saving;
/// the server repeats them.
struct TransactionsRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter

    private let ids = IDGenerator()

    func observe(_ filter: TransactionFilter, limit: Int) -> AsyncValueObservation<
        [TransactionRecord]
    > {
        database.observeFilteredTransactions(filter, limit: limit)
    }

    func find(_ id: String) async throws -> TransactionRecord? {
        try await database.pool.read { try $0.transaction(id: id) }
    }

    /// The admin fee expenses linked to a transfer.
    func fees(of transferId: String) async throws -> [TransactionRecord] {
        try await database.pool.read { try $0.linkedTransactions(of: transferId) }
    }

    func recentSources() async throws -> [String] {
        try await database.pool.read { try $0.recentSources() }
    }

    func lastAccountId(type: String) async throws -> String? {
        try await database.pool.read { try $0.lastAccountId(type: type) }
    }

    private func requireAccount(_ id: String?, missing: ValidationError) async throws
        -> AccountRecord
    {
        guard let id, let account = try await database.pool.read({ try $0.account(id: id) }),
            account.deletedAt == nil
        else { throw missing }
        return account
    }

    /// Validates `draft` and saves it (and, for a transfer, its admin fee). Returns the
    /// transaction id.
    @discardableResult
    func save(_ draft: TransactionDraft) async throws -> String {
        guard let amount = draft.amount else { throw ValidationError.amountRequired }
        if amount <= 0 { throw ValidationError.amountZero }
        if amount > maxAmount { throw ValidationError.amountRange }
        if draft.date > UserClock.today().adding(days: 366) { throw ValidationError.dateFuture }
        let note = draft.note?.trimmingCharacters(in: .whitespaces)
        if (note?.count ?? 0) > 255 { throw ValidationError.noteTooLong }
        let source = draft.source?.trimmingCharacters(in: .whitespaces)
        if (source?.count ?? 0) > 100 { throw ValidationError.sourceTooLong }
        let account = try await requireAccount(draft.accountId, missing: .accountRequired)
        if draft.date < account.openingDate { throw ValidationError.dateBeforeOpening }

        var targetAccount: String?
        var chosenCategory: String?
        var chosenAllocation: String?
        switch draft.type {
        case "transfer":
            guard let target = draft.toAccountId else { throw ValidationError.toAccountRequired }
            if target == draft.accountId { throw ValidationError.sameAccount }
            let destination = try await requireAccount(target, missing: .toAccountRequired)
            if draft.date < destination.openingDate { throw ValidationError.dateBeforeOpening }
            targetAccount = destination.id
        case "expense":
            guard let category = draft.categoryId else { throw ValidationError.categoryRequired }
            guard let chosen = draft.allocation else { throw ValidationError.allocationRequired }
            chosenCategory = category
            chosenAllocation = chosen
        case "income":
            chosenCategory = draft.categoryId
        default:
            break
        }
        let fee = draft.type == "transfer" ? draft.fee : nil
        if let fee, fee <= 0 || fee > maxAmount { throw ValidationError.amountRange }
        let feeCategory = fee == nil ? nil : try await database.pool.read { try $0.feeCategory() }
        if fee != nil && feeCategory == nil { throw ValidationError.categoryRequired }

        let toAccountId = targetAccount
        let categoryId = chosenCategory
        let allocation = chosenAllocation
        let existing = draft.existing
        let id = existing?.id ?? ids.newID()
        let feeId = ids.newID()
        let accountId = account.id
        try await writer.write { [draft] tx in
            try tx.upsert(
                TransactionRecord(
                    id: id, createdAt: existing?.createdAt ?? tx.now, updatedAt: tx.now,
                    deletedAt: nil, serverVersion: existing?.serverVersion, syncStatus: "pending",
                    syncError: nil, type: draft.type, status: existing?.status ?? "posted",
                    transactionDate: draft.date, amount: amount, currency: "IDR",
                    accountId: accountId, toAccountId: toAccountId, categoryId: categoryId,
                    allocation: allocation,
                    source: draft.type == "income" && !(source ?? "").isEmpty ? source : nil,
                    note: (note ?? "").isEmpty ? nil : note,
                    linkedTransactionId: existing?.linkedTransactionId,
                    recurringRuleId: existing?.recurringRuleId))
            if draft.type == "transfer" {
                try Self.saveFee(
                    tx, transferId: id, newFeeId: feeId, fee: fee, feeCategory: feeCategory,
                    accountId: accountId, date: draft.date)
            }
        }
        return id
    }

    /// Creates, updates, or deletes the admin fee expense of a transfer so it matches `fee`
    /// (nil = no fee).
    private static func saveFee(
        _ tx: OutboxTx, transferId: String, newFeeId: String, fee: Int64?,
        feeCategory: CategoryRecord?, accountId: String, date: CivilDate
    ) throws {
        let existing = try tx.db.linkedTransactions(of: transferId)
        guard let fee, let feeCategory else {
            for row in existing { try tx.delete(TransactionRecord.self, id: row.id) }
            return
        }
        let previous = existing.first
        try tx.upsert(
            TransactionRecord(
                id: previous?.id ?? newFeeId, createdAt: previous?.createdAt ?? tx.now,
                updatedAt: tx.now, deletedAt: nil, serverVersion: previous?.serverVersion,
                syncStatus: "pending", syncError: nil, type: "expense", status: "posted",
                transactionDate: date, amount: fee, currency: "IDR", accountId: accountId,
                toAccountId: nil, categoryId: feeCategory.id,
                allocation: feeCategory.defaultAllocation ?? "needs", source: nil, note: nil,
                linkedTransactionId: transferId, recurringRuleId: nil))
    }

    /// Deletes the transaction (and the admin fees linked to a transfer). Returns what was
    /// removed so the delete can be undone.
    func delete(_ id: String) async throws -> [TransactionRecord] {
        guard let row = try await find(id), row.deletedAt == nil else { return [] }
        let removed = [row] + (try await fees(of: id))
        try await writer.write { tx in
            for item in removed.reversed() { try tx.delete(TransactionRecord.self, id: item.id) }
        }
        return removed
    }

    /// Undo of `delete`: writes the rows back, transfer before its fees.
    func restore(_ removed: [TransactionRecord]) async throws {
        try await writer.write { tx in
            for row in removed { try tx.upsert(row) }
        }
    }

    /// Copies the transaction as a new one dated today and returns its id.
    func duplicate(_ id: String) async throws -> String? {
        guard let source = try await find(id) else { return nil }
        let copyId = ids.newID()
        try await writer.write { tx in
            try tx.upsert(
                TransactionRecord(
                    id: copyId, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                    serverVersion: nil, syncStatus: "pending", syncError: nil, type: source.type,
                    status: "posted", transactionDate: UserClock.today(), amount: source.amount,
                    currency: source.currency, accountId: source.accountId,
                    toAccountId: source.toAccountId, categoryId: source.categoryId,
                    allocation: source.allocation, source: source.source, note: source.note,
                    linkedTransactionId: nil, recurringRuleId: nil))
        }
        return copyId
    }
}
