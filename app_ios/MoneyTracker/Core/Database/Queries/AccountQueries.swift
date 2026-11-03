import GRDB

extension Database {
    func account(id: String) throws -> AccountRecord? {
        try AccountRecord.fetchOne(self, key: id)
    }

    /// Live accounts (archived included), in list order.
    func liveAccounts() throws -> [AccountRecord] {
        try AccountRecord.filter(Column("deleted_at") == nil)
            .order(Column("sort_order"), Column("created_at")).fetchAll(self)
    }

    /// Live and not archived: what the free-plan limit counts.
    func openAccountCount() throws -> Int {
        try AccountRecord.filter(Column("deleted_at") == nil && Column("archived_at") == nil)
            .fetchCount(self)
    }

    func maxAccountSortOrder() throws -> Int {
        try Int.fetchOne(self, sql: "SELECT MAX(sort_order) FROM accounts") ?? -1
    }

    func snapshots(accountId: String) throws -> [BalanceSnapshotRecord] {
        try BalanceSnapshotRecord
            .filter(Column("account_id") == accountId && Column("deleted_at") == nil)
            .order(Column("snapshot_date").desc, Column("updated_at").desc).fetchAll(self)
    }
}

extension AppDatabase {
    func observeAccounts() -> AsyncValueObservation<[AccountRecord]> {
        ValueObservation.tracking { try $0.liveAccounts() }.values(in: pool)
    }

    func observeAccount(id: String) -> AsyncValueObservation<AccountRecord?> {
        ValueObservation.tracking {
            try $0.account(id: id).flatMap { $0.deletedAt == nil ? $0 : nil }
        }
        .values(in: pool)
    }

    func observeSnapshots(accountId: String) -> AsyncValueObservation<[BalanceSnapshotRecord]> {
        ValueObservation.tracking { try $0.snapshots(accountId: accountId) }.values(in: pool)
    }
}

extension Database {
    /// Every live snapshot of every account; the reconciliation needs the newest one of each.
    func allSnapshots() throws -> [BalanceSnapshotRecord] {
        try BalanceSnapshotRecord.filter(Column("deleted_at") == nil).fetchAll(self)
    }
}

extension AppDatabase {
    func observeAllSnapshots() -> AsyncValueObservation<[BalanceSnapshotRecord]> {
        ValueObservation.tracking { try $0.allSnapshots() }.values(in: pool)
    }
}
