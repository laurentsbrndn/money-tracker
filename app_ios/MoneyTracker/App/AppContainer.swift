import Observation

/// Composition root. API client, sync, billing and repositories are added here as their
/// phases land; views receive it through the environment.
@Observable
@MainActor
final class AppContainer {
    let config: AppConfig
    let router: AppRouter
    let database: AppDatabase

    init(config: AppConfig = .load(), router: AppRouter = AppRouter()) {
        self.config = config
        self.router = router
        do {
            self.database = try AppDatabase.openDefault()
        } catch {
            // A failed open has no recovery path yet; the splash/error state arrives in Phase 1.
            fatalError("Cannot open local database: \(error)")
        }
    }
}
