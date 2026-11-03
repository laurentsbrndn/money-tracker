import Observation

/// Accounts and categories by ID, kept up to date for every list that shows a transaction (name
/// of the category, name of the account).
@Observable
@MainActor
final class LookupStore {
    private(set) var accounts: [String: AccountRecord] = [:]
    private(set) var categories: [String: CategoryRecord] = [:]

    private let database: AppDatabase
    private var tasks: [Task<Void, Never>] = []

    init(database: AppDatabase) {
        self.database = database
    }

    func start() {
        guard tasks.isEmpty else { return }
        let database = self.database
        tasks = [
            Task { [weak self] in
                while !Task.isCancelled {
                    await forEachValue(database.observeAccounts()) { rows in
                        self?.accounts = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
                    }
                    self?.accounts = [:]
                    try? await Task.sleep(for: .seconds(1))
                }
            },
            Task { [weak self] in
                while !Task.isCancelled {
                    await forEachValue(database.observeCategories()) { rows in
                        self?.categories = Dictionary(
                            uniqueKeysWithValues: rows.map { ($0.id, $0) })
                    }
                    self?.categories = [:]
                    try? await Task.sleep(for: .seconds(1))
                }
            },
        ]
    }
}
