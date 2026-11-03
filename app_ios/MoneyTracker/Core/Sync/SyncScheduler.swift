import Foundation
import SwiftUI

/// Decides when the engine runs (SYNC_PROTOCOL §7 triggers): 2 seconds after a local write, when
/// the app becomes active, when the connection returns, after login, and again after a failure
/// following its backoff.
@MainActor
final class SyncScheduler {
    /// While the app is open it rewrites `foreground_since` this often...
    static let heartbeatInterval: Duration = .seconds(60)
    /// ...and the background task ignores a marker older than this, so a crash blocks it for at
    /// most this long.
    static let foregroundMarkerMaxAge: TimeInterval = 180

    private static let debounce: Duration = .seconds(2)

    private let engine: SyncEngine
    private let database: AppDatabase
    private let connectivity: ConnectivityMonitor
    private let session: SessionStore
    private let background: SyncBackgroundTask

    private var debounceTask: Task<Void, Never>?
    private var followUpTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var connectivityTask: Task<Void, Never>?

    init(
        engine: SyncEngine, database: AppDatabase, connectivity: ConnectivityMonitor,
        session: SessionStore, background: SyncBackgroundTask
    ) {
        self.engine = engine
        self.database = database
        self.connectivity = connectivity
        self.session = session
        self.background = background
    }

    /// Starts listening for the connection coming back. Done on the first activation, not at
    /// launch, so a launch by the background task does not count as "app open".
    private func startListeningIfNeeded() {
        guard connectivityTask == nil else { return }
        connectivityTask = Task { [weak self, connectivity] in
            var wasOnline: Bool?
            for await online in connectivity.changes() {
                if online && wasOnline == false { await self?.syncIfSignedIn() }
                wasOnline = online
            }
        }
    }

    /// Called after every local write.
    func requestSync() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    /// Runs now (pull-to-refresh, becoming active, connection back, login).
    @discardableResult
    func syncNow() async -> SyncOutcome {
        debounceTask?.cancel()
        let outcome = await engine.runOnce()
        await scheduleFollowUp(after: outcome)
        return outcome
    }

    func sessionEstablished() {
        Task { await syncNow() }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startListeningIfNeeded()
            markForeground(true)
            Task { await syncIfSignedIn() }
        case .background:
            markForeground(false)
            background.schedule()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func syncIfSignedIn() async {
        if session.status == .authenticated { await syncNow() }
    }

    private func scheduleFollowUp(after outcome: SyncOutcome) async {
        followUpTask?.cancel()
        var delay: TimeInterval?
        switch outcome {
        case .offline, .failed:
            delay = await engine.retryDelay
        case .synced:
            let due = try? await database.pool.read { try $0.outboxEarliestRetry() }
            if let due { delay = max(1, due.timeIntervalSinceNow) }
        case .skipped, .needsLogin:
            break
        }
        guard let delay else { return }
        followUpTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    /// Tells the background task whether the app is open, so the two never refresh the rotating
    /// refresh token at the same time.
    private func markForeground(_ foreground: Bool) {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        Task { await writeMarker(foreground) }
        guard foreground else { return }
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.heartbeatInterval)
                guard !Task.isCancelled else { return }
                await self?.writeMarker(true)
            }
        }
    }

    private func writeMarker(_ foreground: Bool) async {
        // The database may be mid-reset (logout); the next activation rewrites it.
        try? await database.setSyncState(
            SyncStateKey.foregroundSince, foreground ? TimestampFormat.format(Date()) : nil)
    }
}
