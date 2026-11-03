import Observation

/// Where the app must be, whatever the user taps (APP_FLOWS Flow 1).
enum AppGate: Sendable, Equatable {
    /// Session or database flags not read yet.
    case loading
    /// No session: onboarding and the auth screens.
    case signedOut
    /// Signed in, the first pull has not finished.
    case initialSync
    /// New user who has not finished or skipped the setup wizard.
    case setup
    case ready
}

/// Combines the session with the `sync_state` flags into the gate. The flags are observed for as
/// long as the app lives; an observation that ends (the database was wiped on logout) restarts.
@Observable
@MainActor
final class AppGateStore {
    private(set) var flags: [String: String]?

    private let database: AppDatabase
    private let session: SessionStore
    private var task: Task<Void, Never>?

    init(database: AppDatabase, session: SessionStore) {
        self.database = database
        self.session = session
    }

    var gate: AppGate {
        switch session.status {
        case .loading:
            return .loading
        case .signedOut:
            return .signedOut
        case .authenticated, .needsLogin:
            guard let flags else { return .loading }
            if flags[SyncStateKey.initialSyncDone] != "true" { return .initialSync }
            if flags[SyncStateKey.setupPending] == "true" { return .setup }
            return .ready
        }
    }

    func start() {
        guard task == nil else { return }
        let database = self.database
        task = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    for try await value in database.observeSyncState() { self?.flags = value }
                } catch {}
                // The old database is gone; never act on its flags.
                self?.flags = nil
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
