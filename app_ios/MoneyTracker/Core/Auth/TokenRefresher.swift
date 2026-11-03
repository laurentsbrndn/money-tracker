import Foundation

/// Hands out a valid access token and refreshes it **single-flight**: while one refresh runs,
/// every other caller waits for that same result, so the rotating refresh token is never spent
/// twice (API reuse detection, SYNC_PROTOCOL §11).
actor TokenRefresher {
    private static let refreshMargin: TimeInterval = 60

    private let store: TokenStore
    private let requestRefresh: @Sendable (String) async throws -> AuthTokens
    private let onSessionExpired: @Sendable () async -> Void
    private let now: @Sendable () -> Date

    private var cached: AuthTokens?
    private var inFlight: Task<AuthTokens?, any Error>?

    init(
        store: TokenStore,
        requestRefresh: @escaping @Sendable (String) async throws -> AuthTokens,
        onSessionExpired: @escaping @Sendable () async -> Void,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.requestRefresh = requestRefresh
        self.onSessionExpired = onSessionExpired
        self.now = now
    }

    /// A token usable now, refreshing first when it expires within 60 seconds. Nil when there is
    /// no session or it cannot be renewed. Network failures during a refresh are rethrown.
    func validAccessToken() async throws -> String? {
        if cached == nil { cached = try store.readTokens() }
        guard let tokens = cached else { return nil }
        if !tokens.accessExpires(within: Self.refreshMargin, now: now()) {
            return tokens.accessToken
        }
        return try await refresh()?.accessToken
    }

    /// Called after the server rejected `rejectedToken` as expired. If another request already
    /// renewed the token, that one is returned without a second refresh.
    func renewAfterRejection(rejectedToken: String) async throws -> String? {
        let current = try cached ?? store.readTokens()
        if let current, current.accessToken != rejectedToken,
            !current.accessExpires(within: Self.refreshMargin, now: now())
        {
            cached = current
            return current.accessToken
        }
        return try await refresh()?.accessToken
    }

    /// Stores the tokens of a fresh login.
    func setTokens(_ tokens: AuthTokens) throws {
        try store.writeTokens(tokens)
        cached = tokens
    }

    func clear() {
        cached = nil
        inFlight?.cancel()
        inFlight = nil
    }

    private func refresh() async throws -> AuthTokens? {
        if let running = inFlight { return try await running.value }
        let task = Task { try await self.performRefresh() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    private func performRefresh() async throws -> AuthTokens? {
        guard let stored = try store.readTokens(), !stored.refreshExpired(now: now()) else {
            await expire()
            return nil
        }
        do {
            let renewed = try await requestRefresh(stored.refreshToken)
            try store.writeTokens(renewed)
            cached = renewed
            return renewed
        } catch {
            if case .api(let problem) = APIFailure(error), problem.status == 401 {
                await expire()
                return nil
            }
            throw error
        }
    }

    private func expire() async {
        cached = nil
        await onSessionExpired()
    }
}
