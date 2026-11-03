import Foundation

/// One request failed in a way that retrying the same request cannot fix (413/422 for a whole
/// batch); the entries were already counted.
private struct BatchRejected: Error {
    let message: String
}

/// The sync cycle of SYNC_PROTOCOL §7: push the outbox, then pull changes. An `actor`, so it is
/// single-flight by nature: a call during a run only asks for one more run afterwards.
actor SyncEngine {
    private let database: AppDatabase
    private let remote: SyncRemote
    private let pushApplier: PushApplier
    private let pullApplier: PullApplier
    private let refresher: TokenRefresher
    private let connectivity: ConnectivityMonitor
    private let runStore: SyncRunStore
    private let isAuthenticated: @Sendable () async -> Bool
    private let markNeedsLogin: @Sendable () async -> Void
    private let ids = IDGenerator()

    private var running = false
    private var again = false
    private var failureStreak = 0

    init(
        database: AppDatabase,
        stores: EntityStores,
        remote: SyncRemote,
        refresher: TokenRefresher,
        connectivity: ConnectivityMonitor,
        runStore: SyncRunStore,
        isAuthenticated: @escaping @Sendable () async -> Bool,
        markNeedsLogin: @escaping @Sendable () async -> Void
    ) {
        self.database = database
        self.remote = remote
        self.pushApplier = PushApplier(database: database, stores: stores)
        self.pullApplier = PullApplier(database: database, stores: stores)
        self.refresher = refresher
        self.connectivity = connectivity
        self.runStore = runStore
        self.isAuthenticated = isAuthenticated
        self.markNeedsLogin = markNeedsLogin
    }

    /// Delay before the cycle should be retried after offline or failed runs.
    var retryDelay: TimeInterval? { failureStreak == 0 ? nil : backoff(for: failureStreak) }

    func runOnce() async -> SyncOutcome {
        if running {
            again = true
            return .skipped
        }
        running = true
        await runStore.begin()
        var outcome = await cycle()
        if again && outcome == .synced {
            again = false
            outcome = await cycle()
        }
        again = false
        running = false
        switch outcome {
        case .synced: failureStreak = 0
        case .offline, .failed: failureStreak += 1
        case .skipped, .needsLogin: break
        }
        await runStore.finish(outcome: outcome)
        return outcome
    }

    /// First pull after login (SYNC_PROTOCOL §12): waits for a run in progress, then marks the
    /// initial sync done once a cycle completes.
    func runInitialSync() async -> SyncOutcome {
        var outcome: SyncOutcome
        repeat {
            outcome = await runOnce()
            if outcome == .skipped { try? await Task.sleep(for: .milliseconds(400)) }
        } while outcome == .skipped && !Task.isCancelled
        if outcome == .synced {
            try? await database.setSyncState(SyncStateKey.initialSyncDone, "true")
        }
        return outcome
    }

    private func cycle() async -> SyncOutcome {
        guard await isAuthenticated() else { return .needsLogin }
        guard connectivity.isOnline else { return .offline }
        do {
            guard try await refresher.validAccessToken() != nil else { return .needsLogin }
            let repairKeys = try await push()
            try await pull()
            try await repair(repairKeys)
            try await database.setSyncState(
                SyncStateKey.lastSyncAt, TimestampFormat.format(Date()))
            await runStore.setLastError(nil)
            return .synced
        } catch let rejected as BatchRejected {
            await runStore.setLastError(rejected.message)
            return .failed
        } catch {
            return await classify(error)
        }
    }

    private func classify(_ error: any Error) async -> SyncOutcome {
        switch APIFailure(error) {
        case .api(let problem):
            await runStore.setLastError(problem.code)
            if problem.status == 401 {
                await markNeedsLogin()
                return .needsLogin
            }
            return .failed
        case .unreachable:
            await runStore.setLastError("unreachable")
            return .offline
        case .other:
            // An unexpected error (bad payload, database failure) must not stall the engine; it
            // is retried with backoff.
            await runStore.setLastError(String(describing: type(of: error)))
            return .failed
        }
    }

    /// Sends batches until nothing is ready. Returns the records that need a repair pull.
    private func push() async throws -> Set<String> {
        var repairKeys = Set<String>()
        while true {
            let entries = try await database.pool.read { try $0.outboxAll() }
            guard
                let batch = selectPushBatch(
                    entries.map(\.item), now: Date(), newBatchId: { ids.newID() })
            else { return repairKeys }
            if !batch.isResend {
                let seqs = batch.items.map(\.seq)
                try await database.pool.write {
                    try $0.outboxMarkInFlight(seqs: seqs, batchId: batch.batchId)
                }
            }
            let bySeq = Dictionary(entries.compactMap { e in e.seq.map { ($0, e) } }) { a, _ in a }
            let changes = try batch.items.compactMap { item in
                try bySeq[item.seq].map(wireChange)
            }
            do {
                let results = try await remote.push(batchId: batch.batchId, changes: changes)
                let cursor = try await pullApplier.currentCursor()
                repairKeys.formUnion(
                    try await pushApplier.apply(
                        batch: batch, results: results, now: Date(), cursor: cursor))
            } catch {
                if case .api(let problem) = APIFailure(error), (400..<500).contains(problem.status),
                    problem.status != 401, problem.status != 429
                {
                    try await pushApplier.applyBatchFailure(
                        batch: batch, message: problem.code, now: Date())
                    throw BatchRejected(message: problem.code)
                }
                throw error
            }
        }
    }

    private func wireChange(_ entry: OutboxRecord) throws -> JSONValue {
        var object: [String: JSONValue] = [
            "entity": .string(entry.entity), "op": .string(entry.op), "id": .string(entry.recordId),
            "updated_at": .string(TimestampFormat.format(entry.updatedAt)),
        ]
        if entry.op == "upsert" { object["data"] = try JSONValue.parse(entry.payload) }
        return .object(object)
    }

    private func pull() async throws {
        while true {
            let cursor = try await pullApplier.currentCursor()
            let page = try await remote.pull(since: cursor)
            let written = try await pullApplier.apply(page)
            await runStore.addPulledRows(written)
            if !page.hasMore || page.nextCursor <= cursor { return }
        }
    }

    /// Re-fetches records whose stale push answer can no longer be delivered by a normal pull
    /// (SYNC_PROTOCOL §9.5). One scan from the start per cycle, however many records need it.
    private func repair(_ keys: Set<String>) async throws {
        guard !keys.isEmpty else { return }
        var pending = keys
        var cursor: Int64 = 0
        while !pending.isEmpty {
            let page = try await remote.pull(since: cursor, limit: 1000)
            pending.subtract(try await pullApplier.applyRepair(page, repairKeys: pending))
            if !page.hasMore || page.nextCursor <= cursor { return }
            cursor = page.nextCursor
        }
    }
}
