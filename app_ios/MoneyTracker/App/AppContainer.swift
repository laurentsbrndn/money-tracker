import Observation
import SwiftUI

/// Composition root: the database, the API, sync, and the stores views read. Views receive it
/// through the environment; nothing here is a global singleton.
@Observable
@MainActor
final class AppContainer {
    let config: AppConfig
    let router: AppRouter
    let database: AppDatabase
    let session: SessionStore
    let gate: AppGateStore
    let preferences: PreferencesStore
    let lookups: LookupStore
    let upgrade: UpgradeRequiredStore
    let api: APIEnvironment
    let connectivity: ConnectivityMonitor
    let runStore: SyncRunStore
    let syncStatus: SyncStatusStore
    let engine: SyncEngine
    let scheduler: SyncScheduler
    let background: SyncBackgroundTask
    let stores: EntityStores
    let writer: OutboxWriter
    let ids = IDGenerator()
    let entitlement: EntitlementStore
    let accounts: AccountsRepository
    let categories: CategoriesRepository
    let transactions: TransactionsRepository
    let settings: SettingsRepository
    let setup: SetupRepository
    let failedChanges: FailedChangesService

    init(config: AppConfig = .load(), router: AppRouter = AppRouter()) {
        self.config = config
        self.router = router

        let database: AppDatabase
        do {
            database = try AppDatabase.openDefault()
        } catch {
            // A failed open has no recovery path: the local database is the app's source of truth.
            fatalError("Cannot open local database: \(error)")
        }
        self.database = database

        let keychain = KeychainStore(service: config.bundleID)
        Self.resetKeychainOnFreshInstall(keychain)
        let tokenStore = TokenStore(keychain: keychain)
        let session = SessionStore(tokenStore: tokenStore, database: database)
        let upgrade = UpgradeRequiredStore()
        self.session = session
        self.upgrade = upgrade

        let deviceID: @Sendable () async throws -> String = { try await database.deviceID() }
        let deviceName = UIDevice.current.name
        let refreshClient = APIEnvironment.makeRefreshClient(
            config: config, deviceID: deviceID, deviceName: deviceName)
        let refresher = TokenRefresher(
            store: tokenStore,
            requestRefresh: { refreshToken in
                let output = try await refreshClient.refreshTokens(
                    .init(body: .json(.init(refresh_token: refreshToken))))
                let tokens = try output.ok.body.json.tokens
                return AuthTokens(
                    accessToken: tokens.access_token, accessExpiresAt: tokens.access_expires_at,
                    refreshToken: tokens.refresh_token,
                    refreshExpiresAt: tokens.refresh_expires_at)
            },
            onSessionExpired: { await session.markNeedsLogin() })
        let api = APIEnvironment.make(
            config: config, refresher: refresher, deviceID: deviceID, deviceName: deviceName,
            onUpgradeRequired: { await upgrade.flag() })
        self.api = api
        session.configure(refresher: refresher, client: api.client)
        session.load()

        let connectivity = ConnectivityMonitor()
        let runStore = SyncRunStore()
        let stores = EntityStores()
        let engine = SyncEngine(
            database: database, stores: stores, remote: SyncRemote(api: api.raw),
            refresher: refresher, connectivity: connectivity, runStore: runStore,
            isAuthenticated: { await session.status == .authenticated },
            markNeedsLogin: { await session.markNeedsLogin() })
        let background = SyncBackgroundTask(
            bundleID: config.bundleID, engine: engine, database: database, session: session)
        let scheduler = SyncScheduler(
            engine: engine, database: database, connectivity: connectivity, session: session,
            background: background)
        self.connectivity = connectivity
        self.runStore = runStore
        self.stores = stores
        self.engine = engine
        self.background = background
        self.scheduler = scheduler
        let writer = OutboxWriter(
            database: database, stores: stores,
            onCommitted: { Task { @MainActor in scheduler.requestSync() } })
        let entitlement = EntitlementStore(database: database)
        self.writer = writer
        self.entitlement = entitlement
        self.accounts = AccountsRepository(
            database: database, writer: writer, entitlement: entitlement)
        self.categories = CategoriesRepository(
            database: database, writer: writer, entitlement: entitlement)
        self.transactions = TransactionsRepository(database: database, writer: writer)
        self.settings = SettingsRepository(client: api.client)
        self.setup = SetupRepository(database: database)
        self.failedChanges = FailedChangesService(
            database: database, stores: stores, writer: writer, remote: SyncRemote(api: api.raw))
        self.syncStatus = SyncStatusStore(
            database: database, connectivity: connectivity, session: session, runStore: runStore)
        self.gate = AppGateStore(database: database, session: session)
        self.preferences = PreferencesStore(database: database)
        self.lookups = LookupStore(database: database)

        session.onEstablished = { scheduler.sessionEstablished() }
        syncStatus.start()
        gate.start()
        preferences.start()
        lookups.start()
    }

    #if DEBUG
        /// Previews only (see `Core/Preview`): the same wiring over an in-memory database, an API
        /// whose transport always fails, an in-memory token store, and a fixed connectivity
        /// state. It never touches the network, the Keychain, or `BGTaskScheduler`.
        init(
            preview database: AppDatabase, config: AppConfig, router: AppRouter,
            sessionStatus: SessionStore.Status, user: SessionUser?, online: Bool,
            upgradeRequired: Bool
        ) {
            self.config = config
            self.router = router
            self.database = database

            let tokenStore = TokenStore(
                keychain: KeychainStore(service: "preview", memory: .init()))
            let session = SessionStore(tokenStore: tokenStore, database: database)
            session.applyPreview(status: sessionStatus, user: user)
            let upgrade = UpgradeRequiredStore()
            if upgradeRequired { upgrade.flag() }
            self.session = session
            self.upgrade = upgrade

            let refresher = TokenRefresher(
                store: tokenStore,
                requestRefresh: { _ in throw URLError(.notConnectedToInternet) },
                onSessionExpired: {})
            let transport = PreviewOfflineTransport()
            let api = APIEnvironment(
                client: Client(serverURL: config.apiBaseURL, transport: transport),
                raw: RawAPI(baseURL: config.apiBaseURL, transport: transport, middlewares: []))
            self.api = api
            session.configure(refresher: refresher, client: api.client)

            let connectivity = ConnectivityMonitor(previewOnline: online)
            let runStore = SyncRunStore()
            let stores = EntityStores()
            let engine = SyncEngine(
                database: database, stores: stores, remote: SyncRemote(api: api.raw),
                refresher: refresher, connectivity: connectivity, runStore: runStore,
                isAuthenticated: { false }, markNeedsLogin: {})
            let background = SyncBackgroundTask(
                bundleID: config.bundleID, engine: engine, database: database, session: session)
            let scheduler = SyncScheduler(
                engine: engine, database: database, connectivity: connectivity, session: session,
                background: background)
            self.connectivity = connectivity
            self.runStore = runStore
            self.stores = stores
            self.engine = engine
            self.background = background
            self.scheduler = scheduler
            // Preview writes stay local: nothing asks the scheduler to sync.
            let writer = OutboxWriter(database: database, stores: stores, onCommitted: {})
            let entitlement = EntitlementStore(database: database)
            self.writer = writer
            self.entitlement = entitlement
            self.accounts = AccountsRepository(
                database: database, writer: writer, entitlement: entitlement)
            self.categories = CategoriesRepository(
                database: database, writer: writer, entitlement: entitlement)
            self.transactions = TransactionsRepository(database: database, writer: writer)
            self.settings = SettingsRepository(client: api.client)
            self.setup = SetupRepository(database: database)
            self.failedChanges = FailedChangesService(
                database: database, stores: stores, writer: writer, remote: SyncRemote(api: api.raw)
            )
            self.syncStatus = SyncStatusStore(
                database: database, connectivity: connectivity, session: session,
                runStore: runStore)
            self.gate = AppGateStore(database: database, session: session)
            self.preferences = PreferencesStore(database: database)
            self.lookups = LookupStore(database: database)

            syncStatus.start()
            gate.start()
            preferences.start()
            lookups.start()
        }
    #endif

    /// The Keychain outlives an uninstall; a fresh install must not inherit the old session while
    /// its database is gone.
    private static func resetKeychainOnFreshInstall(_ keychain: KeychainStore) {
        let key = "moneytracker.has_launched"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        try? keychain.deleteAll()
        UserDefaults.standard.set(true, forKey: key)
    }
}
