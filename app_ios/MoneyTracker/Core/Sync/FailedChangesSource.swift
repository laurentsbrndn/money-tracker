import GRDB

/// Reads every row whose last push was refused for good, across all synced tables.
enum FailedChangesSource {
    static func load(_ db: Database) throws -> [FailedChange] {
        var result: [FailedChange] = []
        result += try collect(db, AccountRecord.self) { ($0.name, nil) }
        result += try collect(db, CategoryRecord.self) { ($0.name, nil) }
        result += try collect(db, TransactionRecord.self) {
            ($0.note ?? $0.source ?? "", $0.amount)
        }
        result += try collect(db, BalanceSnapshotRecord.self) { ($0.note ?? "", $0.amount) }
        result += try collect(db, UserSettingsRecord.self) { _ in ("", nil) }
        result += try collect(db, BudgetGoalRecord.self) { ($0.effectiveMonth.description, nil) }
        result += try collect(db, RecurringRuleRecord.self) { ($0.note ?? "", $0.amount) }
        return result
    }

    private static func collect<R: SyncRecord>(
        _ db: Database, _ type: R.Type, label: (R) -> (title: String, amount: Int64?)
    ) throws -> [FailedChange] {
        try R.filter(Column("sync_status") == "failed").fetchAll(db).map { row in
            let text = label(row)
            return FailedChange(
                entity: R.entity, recordId: row.id, title: text.title, amount: text.amount,
                error: row.syncError ?? "", isDelete: row.deletedAt != nil)
        }
    }
}

extension AppDatabase {
    func observeFailedChanges() -> AsyncValueObservation<[FailedChange]> {
        ValueObservation.tracking { try FailedChangesSource.load($0) }.values(in: pool)
    }
}
