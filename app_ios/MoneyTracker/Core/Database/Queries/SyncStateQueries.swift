import GRDB

/// Keys of the `sync_state` key-value table (SYNC_PROTOCOL §5.3).
enum SyncStateKey {
    static let deviceID = "device_id"
    static let pullCursor = "pull_cursor"
    static let lastSyncAt = "last_sync_at"
    static let entitlement = "entitlement"
    static let userID = "user_id"
    static let initialSyncDone = "initial_sync_done"
    static let setupPending = "setup_pending"
    static let foregroundSince = "foreground_since"
}

extension Database {
    func syncState(_ key: String) throws -> String? {
        try SyncStateRecord.fetchOne(self, key: key)?.value
    }

    func setSyncState(_ key: String, _ value: String?) throws {
        if let value {
            try SyncStateRecord(key: key, value: value).save(self)
        } else {
            _ = try SyncStateRecord.deleteOne(self, key: key)
        }
    }
}

extension AppDatabase {
    func syncState(_ key: String) async throws -> String? {
        try await pool.read { try $0.syncState(key) }
    }

    func setSyncState(_ key: String, _ value: String?) async throws {
        try await pool.write { try $0.setSyncState(key, value) }
    }

    /// The installation ID, created once (SYNC_PROTOCOL §5.3). Read first: this runs on every
    /// request, and the write happens only the first time.
    func deviceID(_ ids: IDGenerator = IDGenerator()) async throws -> String {
        if let existing = try await syncState(SyncStateKey.deviceID) { return existing }
        return try await pool.write { db in
            if let existing = try db.syncState(SyncStateKey.deviceID) { return existing }
            let fresh = ids.newID()
            try db.setSyncState(SyncStateKey.deviceID, fresh)
            return fresh
        }
    }

    /// All flags at once, as a stream: drives the app gate.
    func observeSyncState() -> AsyncValueObservation<[String: String]> {
        ValueObservation.tracking { db in
            Dictionary(
                uniqueKeysWithValues: try SyncStateRecord.fetchAll(db).map { ($0.key, $0.value) })
        }.values(in: pool)
    }
}

extension AppDatabase {
    /// Number of changes waiting in the outbox (sent or not).
    func outboxCount() async throws -> Int {
        try await pool.read { try OutboxRecord.fetchCount($0) }
    }
}

extension AppDatabase {
    /// The settings row of the signed-in user (`id` = user ID); nil until the first pull.
    func observeUserSettings() -> AsyncValueObservation<UserSettingsRecord?> {
        ValueObservation.tracking { db in
            try UserSettingsRecord.filter(Column("deleted_at") == nil).fetchOne(db)
        }.values(in: pool)
    }
}
