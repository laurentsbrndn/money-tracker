import GRDB

extension AppDatabase {
    /// Fires after any commit that touches the data the notification schedule is built from:
    /// settings, transactions, snapshots, accounts, and goals. That includes rows a pull wrote.
    func observeNotificationInputs() -> AsyncValueObservation<Int> {
        ValueObservation.tracking(
            regions: [
                UserSettingsRecord.all(), TransactionRecord.all(), BalanceSnapshotRecord.all(),
                AccountRecord.all(), BudgetGoalRecord.all(),
            ], fetch: { _ in 0 }
        ).values(in: pool)
    }
}
