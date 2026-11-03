import Foundation
import Observation
import OpenAPIRuntime

/// Signing in as a different user than the one who owns the local database (SYNC_PROTOCOL §11).
/// The caller must warn the user (`pendingChanges` unsent changes would be lost) and sign in
/// again with the local data discarded.
struct UserMismatchError: Error, Sendable {
    let pendingChanges: Int
}

/// Owns who is signed in (FRONTEND_IOS §4.2). Tokens live in the Keychain; the user ID of the
/// local database in `sync_state`.
@Observable
@MainActor
final class SessionStore {
    enum Status: Sendable {
        /// Storage has not been read yet.
        case loading
        case signedOut
        case authenticated
        /// Refreshing the token failed for good; data and outbox are kept (SYNC_PROTOCOL §11)
        /// and the user is asked to sign in again.
        case needsLogin
    }

    private(set) var status: Status = .loading
    private(set) var user: SessionUser?

    var hasSession: Bool { status == .authenticated || status == .needsLogin }

    private let tokenStore: TokenStore
    private let database: AppDatabase
    private var refresher: TokenRefresher?
    private var client: Client?

    /// Called after a login or registration succeeded, so sync can start.
    var onEstablished: (() -> Void)?

    init(tokenStore: TokenStore, database: AppDatabase) {
        self.tokenStore = tokenStore
        self.database = database
    }

    /// Late binding: the refresher and client need this store (session expiry), and this store
    /// needs them (logout), so they are attached after construction.
    func configure(refresher: TokenRefresher, client: Client) {
        self.refresher = refresher
        self.client = client
    }

    /// Reads the stored session. Called once at launch.
    func load() {
        guard (try? tokenStore.readTokens()) != nil, let stored = try? tokenStore.readUser()
        else {
            // A half-written session (tokens without user or the reverse) is not usable.
            status = .signedOut
            user = nil
            return
        }
        user = stored
        status = ((try? tokenStore.readNeedsLogin()) ?? false) ? .needsLogin : .authenticated
    }

    /// Starts a session from a login/register response. Throws `UserMismatchError` if the local
    /// database belongs to another user and `discardLocalData` is false.
    func establish(_ response: Components.Schemas.AuthResponse, discardLocalData: Bool = false)
        async throws
    {
        let owner = try await database.syncState(SyncStateKey.userID)
        if let owner, owner != response.user.id {
            guard discardLocalData else {
                throw UserMismatchError(pendingChanges: try await database.outboxCount())
            }
            try await wipeLocalData()
        }
        let tokens = AuthTokens(
            accessToken: response.tokens.access_token,
            accessExpiresAt: response.tokens.access_expires_at,
            refreshToken: response.tokens.refresh_token,
            refreshExpiresAt: response.tokens.refresh_expires_at)
        let sessionUser = SessionUser(response.user)
        try await refresher?.setTokens(tokens)
        try tokenStore.writeUser(sessionUser)
        try tokenStore.writeNeedsLogin(false)
        try await database.setSyncState(SyncStateKey.userID, sessionUser.id)
        if response.is_new_user {
            try await database.setSyncState(SyncStateKey.setupPending, "true")
        }
        user = sessionUser
        status = .authenticated
        onEstablished?()
    }

    /// Replaces the stored user after a profile or verification change.
    func updateUser(_ updated: SessionUser) {
        try? tokenStore.writeUser(updated)
        user = updated
    }

    /// Refreshing failed for good (SYNC_PROTOCOL §11). Data and outbox stay.
    func markNeedsLogin() {
        guard status == .authenticated else { return }
        try? tokenStore.writeNeedsLogin(true)
        status = .needsLogin
    }

    /// Revokes the refresh token (best effort) and deletes all local data.
    func logout() async {
        if let tokens = try? tokenStore.readTokens(), let client {
            _ = try? await client.logout(
                .init(body: .json(.init(refresh_token: tokens.refreshToken))))
        }
        await clearLocalSession()
    }

    /// Ends the session and deletes the local database without calling the API (after account
    /// deletion, or when logout has already been requested).
    func clearLocalSession() async {
        try? tokenStore.clear()
        await refresher?.clear()
        status = .signedOut
        user = nil
        try? await wipeLocalData()
    }

    private func wipeLocalData() async throws {
        // Let the screens that observe the database leave the tree before the file goes away.
        try? await Task.sleep(for: .milliseconds(150))
        try database.wipeAndReopen()
    }
}
