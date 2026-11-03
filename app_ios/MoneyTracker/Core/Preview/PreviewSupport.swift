#if DEBUG
    import GRDB
    import HTTPTypes
    import OpenAPIRuntime
    import SwiftUI

    /// The states a preview can open a screen in. `dark` is the populated data in dark mode.
    enum PreviewVariant: String, CaseIterable, Identifiable {
        case empty
        case populated
        case hiddenAmounts
        case syncing
        case pending
        case offline
        case needsLogin
        case attention
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .empty: "Kosong"
            case .populated: "Berisi"
            case .hiddenAmounts: "Nominal disembunyikan"
            case .syncing: "Menyinkronkan"
            case .pending: "Menunggu sync"
            case .offline: "Offline"
            case .needsLogin: "Perlu login"
            case .attention: "Perlu perhatian"
            case .dark: "Mode gelap"
            }
        }

        var colorScheme: ColorScheme? { self == .dark ? .dark : nil }
    }

    /// A transport that never leaves the process: every request fails as if offline.
    struct PreviewOfflineTransport: ClientTransport {
        func send(
            _ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String
        ) async throws -> (HTTPResponse, HTTPBody?) {
            throw URLError(.notConnectedToInternet)
        }
    }

    extension SessionUser {
        /// The signed-in user of previews.
        static func preview(emailVerified: Bool = true) -> SessionUser {
            SessionUser(
                id: PreviewSampleData.userID, name: "Brandon", email: "brandon@example.com",
                emailVerified: emailVerified, hasPassword: true, providers: ["password"])
        }

        init(
            id: String, name: String, email: String?, emailVerified: Bool, hasPassword: Bool,
            providers: [String]
        ) {
            self.id = id
            self.name = name
            self.email = email
            self.emailVerified = emailVerified
            self.hasPassword = hasPassword
            self.providers = providers
        }
    }

    extension AppContainer {
        /// A container over an in-memory database seeded for `variant`. No network, Keychain, or
        /// background task is involved.
        static func preview(_ variant: PreviewVariant = .populated) -> AppContainer {
            UserClock.pinTodayForPreviews(PreviewSampleData.today)
            let database: AppDatabase
            do {
                let queue = try DatabaseQueue()
                try DatabaseMigrations.makeMigrator().migrate(queue)
                try queue.write {
                    try PreviewSampleData.seed($0, populated: variant != .empty, variant: variant)
                }
                database = AppDatabase(writer: queue)
            } catch {
                fatalError("Cannot build the preview database: \(error)")
            }
            let config = AppConfig(
                apiBaseURL: URL(fileURLWithPath: "/"), revenueCatKey: "", googleClientID: "",
                appVersion: "preview", bundleID: "com.brandon.MoneyTracker.preview")
            let container = AppContainer(
                preview: database, config: config, router: AppRouter(),
                sessionStatus: variant == .needsLogin ? .needsLogin : .authenticated,
                user: .preview(), online: variant != .offline, upgradeRequired: false)
            if variant == .syncing { container.runStore.begin() }
            return container
        }

        /// The signed-out state, for the auth screens.
        static func previewSignedOut() -> AppContainer {
            let container = AppContainer.preview(.empty)
            container.session.applyPreview(status: .signedOut, user: nil)
            return container
        }
    }

    /// Builds the preview container once per appearance (not on every view update) and puts it
    /// in the environment together with the app's locale and the variant's color scheme.
    struct PreviewHost<Content: View>: View {
        let variant: PreviewVariant
        var signedOut = false
        @ViewBuilder let content: (AppContainer) -> Content

        @State private var container: AppContainer?

        var body: some View {
            Group {
                if let container {
                    content(container).environment(container)
                } else {
                    Color.clear
                }
            }
            .environment(\.locale, Locale(identifier: "id_ID"))
            .preferredColorScheme(variant.colorScheme)
            .onAppear {
                if container == nil {
                    container = signedOut ? .previewSignedOut() : .preview(variant)
                }
            }
        }
    }

    /// A `NavigationStack` bound to one tab's path of the router, so rows that push a route
    /// (`router.push`) work inside a preview.
    struct PreviewStack<Content: View>: View {
        let container: AppContainer
        let tab: AppTab
        @ViewBuilder let content: () -> Content

        var body: some View {
            @Bindable var router = container.router
            switch tab {
            case .accounts:
                NavigationStack(path: $router.accountsPath) {
                    content().routeDestinations(container)
                }
            case .budget:
                NavigationStack(path: $router.budgetPath) {
                    content().routeDestinations(container)
                }
            case .more:
                NavigationStack(path: $router.morePath) {
                    content().routeDestinations(container)
                }
            case .transactions:
                NavigationStack(path: $router.transactionsPath) {
                    content().routeDestinations(container)
                }
            default:
                NavigationStack(path: $router.dashboardPath) {
                    content().routeDestinations(container)
                }
            }
        }
    }
#endif
