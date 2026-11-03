import BackgroundTasks
import Foundation

/// The `BGAppRefreshTask` that syncs while the app is closed (FRONTEND_IOS §4.3). The identifier
/// is `<bundle id>.sync` and is listed in `Info.plist`. iOS decides when, and how often, it
/// actually runs; the request below only sets the earliest time (30 minutes).
@MainActor
final class SyncBackgroundTask {
    private static let interval: TimeInterval = 30 * 60

    private let identifier: String
    private let engine: SyncEngine
    private let database: AppDatabase
    private let session: SessionStore

    init(bundleID: String, engine: SyncEngine, database: AppDatabase, session: SessionStore) {
        self.identifier = bundleID + ".sync"
        self.engine = engine
        self.database = database
        self.session = session
    }

    /// Must run before the app finishes launching.
    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) {
            [weak self] task in
            MainActor.assumeIsolated {
                guard let self, let refresh = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handle(refresh)
            }
        }
    }

    /// Asks for the next run; called when the app goes to the background and after every run.
    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.interval)
        // Fails on the simulator and when Background App Refresh is off; the next
        // background transition asks again.
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handle(_ task: BGAppRefreshTask) {
        schedule()
        let work = Task { () -> Bool in
            if await foregroundMarkerIsFresh() { return true }
            guard session.status == .authenticated,
                (try? await database.syncState(SyncStateKey.initialSyncDone)) == "true"
            else { return true }
            let outcome = await engine.runOnce()
            return outcome == .synced || outcome == .offline || outcome == .skipped
        }
        task.expirationHandler = { work.cancel() }
        Task {
            task.setTaskCompleted(success: await work.value)
        }
    }

    /// The app is open (or crashed within the last 3 minutes): it does the sync itself.
    private func foregroundMarkerIsFresh() async -> Bool {
        guard let text = try? await database.syncState(SyncStateKey.foregroundSince),
            let since = TimestampFormat.parse(text)
        else { return false }
        return Date().timeIntervalSince(since) < SyncScheduler.foregroundMarkerMaxAge
    }
}
