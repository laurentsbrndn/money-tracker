import Foundation
import GRDB

/// Budget goals. Reads are live streams; the one write goes through the `OutboxWriter`. The row
/// id is deterministic (SYNC_PROTOCOL §3), so two devices setting a goal for the same month write
/// the same row.
struct BudgetRepository: Sendable {
    let database: AppDatabase
    let writer: OutboxWriter

    private let ids = IDGenerator()

    init(database: AppDatabase, writer: OutboxWriter) {
        self.database = database
        self.writer = writer
    }

    func observeGoals() -> AsyncValueObservation<[BudgetGoalRecord]> {
        database.observeBudgetGoals()
    }

    /// Saves the goal that applies from `month` on (BUSINESS_RULES §6). Returns false, writing
    /// nothing, when the month already has exactly this goal.
    @discardableResult
    func saveGoal(month: YearMonth, input: BudgetGoalInput) async throws -> Bool {
        for pct in [input.needs, input.wants, input.savings] where pct < 0 || pct > 100 {
            throw ValidationError.goalPercentRange
        }
        if input.total != 100 { throw ValidationError.goalTotal }
        if let planned = input.plannedIncome, planned < 0 || planned > maxAmount {
            throw ValidationError.plannedIncomeRange
        }
        guard let userID = try await database.syncState(SyncStateKey.userID) else {
            throw ValidationError.settingsMissing
        }
        let id = ids.budgetGoalID(userID: userID, month: month.description)
        return try await writer.write { tx in
            let existing = try tx.db.budgetGoal(id: id)
            if let existing, existing.deletedAt == nil, existing.needsPct == input.needs,
                existing.wantsPct == input.wants, existing.savingsPct == input.savings,
                existing.plannedIncome == input.plannedIncome
            {
                return false
            }
            try tx.upsert(
                BudgetGoalRecord(
                    id: id, createdAt: existing?.createdAt ?? tx.now, updatedAt: tx.now,
                    deletedAt: nil, serverVersion: existing?.serverVersion,
                    syncStatus: "pending", syncError: nil, effectiveMonth: month.first,
                    needsPct: input.needs, wantsPct: input.wants, savingsPct: input.savings,
                    plannedIncome: input.plannedIncome))
            return true
        }
    }
}
