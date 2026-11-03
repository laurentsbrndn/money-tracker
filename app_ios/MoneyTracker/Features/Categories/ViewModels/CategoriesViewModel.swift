import Foundation
import Observation

/// Manage categories (APP_FLOWS Flow 7): tabs for expense and income, hide, archive, reorder,
/// delete.
@Observable
@MainActor
final class CategoriesViewModel {
    var type = "expense"
    private(set) var all: [CategoryRecord] = []
    private(set) var loaded = false
    var errorMessage: String?

    private let repository: CategoriesRepository

    init(container: AppContainer) {
        repository = container.categories
    }

    var shown: [CategoryRecord] {
        all.filter { $0.type == type }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func start() async {
        await forEachValue(repository.observeAll()) {
            self.all = $0
            self.loaded = true
        }
    }

    func setHidden(_ category: CategoryRecord, hidden: Bool) async {
        await run { try await self.repository.setHidden(category, hidden: hidden) }
    }

    func setArchived(_ category: CategoryRecord, archived: Bool) async {
        await run { try await self.repository.setArchived(category, archived: archived) }
    }

    func delete(_ category: CategoryRecord) async {
        await run { try await self.repository.delete(category.id) }
    }

    func move(from source: IndexSet, to destination: Int) async {
        var ordered = shown
        ordered.move(fromOffsets: source, toOffset: destination)
        await run { try await self.repository.reorder(ordered) }
    }

    private func run(_ action: () async throws -> Void) async {
        do { try await action() } catch { errorMessage = ErrorMessages.describe(error) }
    }
}
