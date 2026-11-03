import Observation

/// The first pull after login (SYNC_PROTOCOL §12).
@Observable
@MainActor
final class InitialSyncViewModel {
    enum State: Equatable {
        case syncing
        case offline
        case failed
        case needsLogin
    }

    private(set) var state = State.syncing

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var pulledRows: Int { container.runStore.pulledRows }

    /// Pulls until done; the app gate moves on by itself once `initial_sync_done` is written.
    func run() async {
        state = .syncing
        switch await container.engine.runInitialSync() {
        case .synced, .skipped: break
        case .offline: state = .offline
        case .failed: state = .failed
        case .needsLogin: state = .needsLogin
        }
    }
}
