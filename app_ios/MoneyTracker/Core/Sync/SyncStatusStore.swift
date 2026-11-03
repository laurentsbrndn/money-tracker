import Foundation
import Observation

/// What the `SyncBadge` shows (FRONTEND_FLUTTER §4.3, same states on iOS).
enum SyncBadgeState: Equatable {
    case synced
    case syncing
    /// Entries waiting in the outbox.
    case pending(Int)
    case offline
    case needsLogin
    /// Records the server refused for good.
    case attention(Int)
}

/// Combines the session, the connection, the outbox and the engine into one badge, and keeps the
/// counts the sync screen shows. Observes the database in the background for as long as the app
/// lives; an observation that ends (the database was wiped on logout) is started again.
@Observable
@MainActor
final class SyncStatusStore {
    private(set) var pendingCount = 0
    private(set) var failedChanges: [FailedChange] = []
    private(set) var lastSyncAt: Date?
    private(set) var isOnline = true

    private let database: AppDatabase
    private let connectivity: ConnectivityMonitor
    private let session: SessionStore
    private let runStore: SyncRunStore
    private var tasks: [Task<Void, Never>] = []

    init(
        database: AppDatabase, connectivity: ConnectivityMonitor, session: SessionStore,
        runStore: SyncRunStore
    ) {
        self.database = database
        self.connectivity = connectivity
        self.session = session
        self.runStore = runStore
    }

    var badge: SyncBadgeState {
        if session.status == .needsLogin { return .needsLogin }
        if !failedChanges.isEmpty { return .attention(failedChanges.count) }
        if !isOnline { return .offline }
        if pendingCount > 0 { return .pending(pendingCount) }
        if runStore.running { return .syncing }
        return .synced
    }

    func start() {
        guard tasks.isEmpty else { return }
        let database = self.database
        tasks = [
            Task { [weak self, connectivity] in
                for await online in connectivity.changes() { self?.isOnline = online }
            },
            keepObserving(
                reset: { [weak self] in self?.pendingCount = 0 },
                body: { [weak self] in
                    for try await count in database.observePendingChangeCount() {
                        self?.pendingCount = count
                    }
                }),
            keepObserving(
                reset: { [weak self] in self?.failedChanges = [] },
                body: { [weak self] in
                    for try await list in database.observeFailedChanges() {
                        self?.failedChanges = list
                    }
                }),
            keepObserving(
                reset: { [weak self] in self?.lastSyncAt = nil },
                body: { [weak self] in
                    for try await flags in database.observeSyncState() {
                        self?.lastSyncAt = flags[SyncStateKey.lastSyncAt].flatMap(
                            TimestampFormat.parse)
                    }
                }),
        ]
    }

    private func keepObserving(
        reset: @escaping @MainActor () -> Void, body: @escaping @MainActor () async throws -> Void
    ) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                do { try await body() } catch {}
                reset()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
