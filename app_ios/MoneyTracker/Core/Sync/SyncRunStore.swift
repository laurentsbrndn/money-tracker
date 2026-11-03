import Observation

/// What the sync engine is doing, for the UI. Written by the engine, read by views.
@Observable
@MainActor
final class SyncRunStore {
    private(set) var running = false
    private(set) var outcome: SyncOutcome?
    /// Rows written by pulls since the app started; drives the initial sync progress.
    private(set) var pulledRows = 0
    private(set) var lastError: String?

    func begin() {
        running = true
    }

    func finish(outcome: SyncOutcome) {
        running = false
        self.outcome = outcome
    }

    func addPulledRows(_ count: Int) {
        pulledRows += count
    }

    func setLastError(_ error: String?) {
        lastError = error
    }
}
