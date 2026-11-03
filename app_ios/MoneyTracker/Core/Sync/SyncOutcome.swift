/// How the last sync run ended.
enum SyncOutcome: Sendable, Equatable {
    /// Everything pushed and pulled.
    case synced
    /// Another run was already going; it will run again afterwards.
    case skipped
    /// No connection (or the request never got through).
    case offline
    /// Not signed in, or the session cannot be renewed (SYNC_PROTOCOL §11).
    case needsLogin
    /// The server answered with an error; retried with backoff.
    case failed
}
