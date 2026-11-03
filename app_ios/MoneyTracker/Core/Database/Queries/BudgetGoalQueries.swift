import GRDB

extension Database {
    func budgetGoal(id: String) throws -> BudgetGoalRecord? {
        try BudgetGoalRecord.fetchOne(self, key: id)
    }

    func liveBudgetGoals() throws -> [BudgetGoalRecord] {
        try BudgetGoalRecord.filter(Column("deleted_at") == nil).fetchAll(self)
    }
}

extension AppDatabase {
    func observeBudgetGoals() -> AsyncValueObservation<[BudgetGoalRecord]> {
        ValueObservation.tracking { try $0.liveBudgetGoals() }.values(in: pool)
    }
}
