/// Flags of the one-time setup wizard (APP_FLOWS Flow 1, step 6). The data the wizard edits goes
/// through the accounts and categories repositories.
struct SetupRepository: Sendable {
    let database: AppDatabase

    /// The Cash account created by the server's onboarding seed.
    func findCash() async throws -> AccountRecord? {
        try await database.pool.read { try $0.liveAccounts() }.first { $0.type == "cash" }
    }

    /// Wizard finished or skipped: it is never shown again for this user.
    func markDone() async throws {
        try await database.setSyncState(SyncStateKey.setupPending, "false")
    }
}
