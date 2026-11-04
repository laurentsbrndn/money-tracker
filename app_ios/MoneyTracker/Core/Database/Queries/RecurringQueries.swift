import GRDB

extension Database {
    func recurringRule(id: String) throws -> RecurringRuleRecord? {
        try RecurringRuleRecord.fetchOne(self, key: id)
    }

    /// Live rules that are not paused: the ones the generator runs (BUSINESS_RULES §5.2).
    func runningRecurringRules() throws -> [RecurringRuleRecord] {
        try RecurringRuleRecord
            .filter(Column("deleted_at") == nil && Column("is_paused") == false).fetchAll(self)
    }
}

extension AppDatabase {
    /// Live recurring rules, in creation order.
    func observeRecurringRules() -> AsyncValueObservation<[RecurringRuleRecord]> {
        ValueObservation.tracking { db in
            try RecurringRuleRecord.filter(Column("deleted_at") == nil)
                .order(Column("created_at")).fetchAll(db)
        }.values(in: pool)
    }

    /// Fires when any recurring rule changes (a pull included), for the generator.
    func observeRecurringRuleVersions() -> AsyncValueObservation<[String]> {
        ValueObservation.tracking { db in
            try RecurringRuleRecord.order(Column("id")).fetchAll(db).map {
                "\($0.id):\($0.updatedAt.timeIntervalSince1970):\($0.isPaused)"
            }
        }.values(in: pool)
    }
}
