import Foundation
import GRDB

/// Recurring rules. Reads are live streams from the local database; every write goes through the
/// `OutboxWriter` (SYNC_PROTOCOL §6). The checks of BUSINESS_RULES §5-§7 run first; the server
/// repeats them on push.
struct RecurringRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter
    let entitlement: EntitlementStore

    private let ids = IDGenerator()

    init(database: AppDatabase, writer: OutboxWriter, entitlement: EntitlementStore) {
        self.database = database
        self.writer = writer
        self.entitlement = entitlement
    }

    func observeAll() -> AsyncValueObservation<[RecurringRuleRecord]> {
        database.observeRecurringRules()
    }

    func find(_ id: String) async throws -> RecurringRuleRecord? {
        try await database.pool.read { try $0.recurringRule(id: id) }
    }

    private func requirePremium() async throws {
        if await !entitlement.isPremium() { throw PlanLimitError(kind: .recurring) }
    }

    private func requireAccount(_ id: String?, missing: ValidationError) async throws
        -> AccountRecord
    {
        guard let id, let account = try await database.pool.read({ try $0.account(id: id) }),
            account.deletedAt == nil
        else { throw missing }
        return account
    }

    private func validate(_ input: RecurringRuleInput) async throws {
        guard let amount = input.amount else { throw ValidationError.amountRequired }
        if amount <= 0 { throw ValidationError.amountZero }
        if amount > maxAmount { throw ValidationError.amountRange }
        if (input.note?.trimmingCharacters(in: .whitespaces).count ?? 0) > 255 {
            throw ValidationError.noteTooLong
        }
        if (input.source?.trimmingCharacters(in: .whitespaces).count ?? 0) > 100 {
            throw ValidationError.sourceTooLong
        }
        if input.intervalCount < 1 || input.intervalCount > 366 {
            throw ValidationError.recurringIntervalRange
        }
        if let end = input.endDate, end < input.startDate {
            throw ValidationError.recurringEndBeforeStart
        }
        try validateSchedule(input)

        let account = try await requireAccount(input.accountId, missing: .accountRequired)
        if input.startDate < account.openingDate { throw ValidationError.dateBeforeOpening }
        switch input.type {
        case "transfer":
            guard let target = input.toAccountId else { throw ValidationError.toAccountRequired }
            if target == input.accountId { throw ValidationError.sameAccount }
            let destination = try await requireAccount(target, missing: .toAccountRequired)
            if input.startDate < destination.openingDate { throw ValidationError.dateBeforeOpening }
        case "expense":
            if input.categoryId == nil { throw ValidationError.categoryRequired }
            if input.allocation == nil { throw ValidationError.allocationRequired }
        default:
            break
        }
    }

    /// The schedule fields of the frequency, and only those (DATA_MODEL §5).
    private func validateSchedule(_ input: RecurringRuleInput) throws {
        let invalid = ValidationError.recurringScheduleInvalid
        switch input.frequency {
        case .daily:
            break
        case .weekly:
            guard let dow = input.dayOfWeek, (1...7).contains(dow) else { throw invalid }
        case .monthly:
            guard let dom = input.dayOfMonth, (1...31).contains(dom) else { throw invalid }
        case .yearly:
            // 29 Feb is allowed (28 Feb in other years); 30 Feb and 31 Apr never occur.
            guard let moy = input.monthOfYear, (1...12).contains(moy),
                let dom = input.dayOfMonth,
                (1...CivilDate.daysInMonth(year: 2024, month: moy)).contains(dom)
            else { throw invalid }
        }
    }

    /// Creates a rule, or saves the edit of `existing`. Creating needs premium; editing a rule
    /// that is running does not (BUSINESS_RULES §7). Returns the rule id.
    @discardableResult
    func save(_ input: RecurringRuleInput, existing: RecurringRuleRecord? = nil) async throws
        -> String
    {
        try await validate(input)
        if existing == nil || existing?.deletedAt != nil { try await requirePremium() }
        let id = existing?.id ?? ids.newID()
        let usesDayOfMonth = input.frequency == .monthly || input.frequency == .yearly
        let transfer = input.type == "transfer"
        let expense = input.type == "expense"
        let note = input.note?.trimmingCharacters(in: .whitespaces) ?? ""
        let source = input.source?.trimmingCharacters(in: .whitespaces) ?? ""
        let amount = input.amount ?? 0
        let accountId = input.accountId ?? ""
        try await writer.write { tx in
            try tx.upsert(
                RecurringRuleRecord(
                    id: id, createdAt: existing?.createdAt ?? tx.now, updatedAt: tx.now,
                    deletedAt: nil, serverVersion: existing?.serverVersion, syncStatus: "pending",
                    syncError: nil, type: input.type, amount: amount, accountId: accountId,
                    toAccountId: transfer ? input.toAccountId : nil,
                    categoryId: transfer ? nil : input.categoryId,
                    allocation: expense ? input.allocation : nil,
                    source: input.type == "income" && !source.isEmpty ? source : nil,
                    note: note.isEmpty ? nil : note, frequency: input.frequency.rawValue,
                    intervalCount: input.intervalCount,
                    dayOfWeek: input.frequency == .weekly ? input.dayOfWeek : nil,
                    dayOfMonth: usesDayOfMonth ? input.dayOfMonth : nil,
                    monthOfYear: input.frequency == .yearly ? input.monthOfYear : nil,
                    startDate: input.startDate, endDate: input.endDate, mode: input.mode,
                    isPaused: existing?.isPaused ?? false,
                    // An edit only affects dates after the ones already created.
                    lastGeneratedDate: existing?.lastGeneratedDate))
        }
        return id
    }

    /// Pauses or resumes a rule. Resuming needs premium: a rule the server paused when premium
    /// ended stays paused until the plan is back.
    func setPaused(_ rule: RecurringRuleRecord, paused: Bool) async throws {
        if !paused { try await requirePremium() }
        var changed = rule
        changed.isPaused = paused
        let updated = changed
        try await writer.write { tx in try tx.upsert(updated) }
    }

    /// Deletes the rule; transactions it already created stay.
    func delete(_ id: String) async throws {
        try await writer.write { tx in try tx.delete(RecurringRuleRecord.self, id: id) }
    }
}
