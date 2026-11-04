import Foundation
import GRDB

/// Creates the transactions recurring rules have come due for, on the device (BUSINESS_RULES
/// §5.2). The server's daily job does the same with the same ids, so a date is never recorded
/// twice: the id of an occurrence is UUIDv5(`rule id|date`), and a row that already exists, even
/// a deleted one, is left alone (SYNC_PROTOCOL S12).
struct RecurringGenerator: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter
    let entitlement: EntitlementStore

    private let ids = IDGenerator()

    /// Only premium users have occurrences created.
    func run(today: CivilDate = UserClock.today()) async throws -> GenerationResult {
        guard await entitlement.isPremium() else { return GenerationResult() }
        let rules = try await database.pool.read { try $0.runningRecurringRules() }
        var total = GenerationResult()
        for rule in rules {
            let due = DomainRules.occurrences(
                rule: rule.schedule, lastGenerated: rule.lastGeneratedDate, today: today)
            if due.isEmpty { continue }
            let result = try await generate(rule, due: due)
            total.created += result.created
            total.pendingConfirmation += result.pendingConfirmation
        }
        return total
    }

    /// One transaction per rule: its occurrences and its new `last_generated_date` are saved
    /// together.
    private func generate(_ rule: RecurringRuleRecord, due: [CivilDate]) async throws
        -> GenerationResult
    {
        let ids = self.ids
        return try await writer.write { tx in
            let opening = try Self.openingDate(of: rule, db: tx.db)
            let status =
                rule.mode == "confirm"
                ? TransactionStatus.pendingConfirmation.rawValue
                : TransactionStatus.posted.rawValue
            var created = 0
            // A rule whose account or category is gone records nothing, but still moves on, so
            // it is not "due" for ever (the server does the same).
            if let opening {
                for date in due where date >= opening {
                    let id = ids.recurringOccurrenceID(ruleID: rule.id, date: date)
                    if try tx.db.transaction(id: id) != nil { continue }
                    try tx.upsert(
                        TransactionRecord(
                            id: id, createdAt: tx.now, updatedAt: tx.now, deletedAt: nil,
                            serverVersion: nil, syncStatus: "pending", syncError: nil,
                            type: rule.type, status: status, transactionDate: date,
                            amount: rule.amount, currency: "IDR", accountId: rule.accountId,
                            toAccountId: rule.toAccountId, categoryId: rule.categoryId,
                            allocation: rule.allocation, source: rule.source, note: rule.note,
                            linkedTransactionId: nil, recurringRuleId: rule.id))
                    created += 1
                }
            }
            var updated = rule
            updated.lastGeneratedDate = due.last
            try tx.upsert(updated)
            return GenerationResult(
                created: created,
                pendingConfirmation: status == TransactionStatus.posted.rawValue ? 0 : created)
        }
    }

    /// The latest opening date among the template's accounts, or nil when an account or the
    /// category is missing or deleted.
    private static func openingDate(of rule: RecurringRuleRecord, db: Database) throws
        -> CivilDate?
    {
        var opening: CivilDate?
        for id in [rule.accountId] + (rule.toAccountId.map { [$0] } ?? []) {
            guard let account = try db.account(id: id), account.deletedAt == nil else {
                return nil
            }
            if opening == nil || account.openingDate > opening! { opening = account.openingDate }
        }
        if let categoryId = rule.categoryId {
            guard let category = try db.category(id: categoryId), category.deletedAt == nil else {
                return nil
            }
        }
        return opening
    }
}
