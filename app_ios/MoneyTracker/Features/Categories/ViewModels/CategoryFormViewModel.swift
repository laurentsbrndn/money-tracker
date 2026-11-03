import Observation

/// Create or edit a category.
@Observable
@MainActor
final class CategoryFormViewModel {
    let categoryId: String?

    var type: String
    var name = ""
    var icon = "other"
    var color = CategoryIcons.palette[0]
    var allocation = "needs"
    private(set) var busy = false
    private(set) var saved = false
    var errorMessage: String?

    private var existing: CategoryRecord?
    private let repository: CategoriesRepository

    init(container: AppContainer, categoryId: String?, type: String?) {
        self.categoryId = categoryId
        self.type = type ?? "expense"
        repository = container.categories
    }

    var isEditing: Bool { categoryId != nil }

    /// A seeded category keeps its icon (the fee category is found by it).
    var canChangeIcon: Bool { !(existing?.isDefault ?? false) }

    func load() async {
        guard let categoryId, existing == nil, let category = try? await repository.find(categoryId)
        else { return }
        existing = category
        type = category.type
        name = category.name
        icon = category.icon
        color = category.color
        allocation = category.defaultAllocation ?? "needs"
    }

    func save() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        let chosen = type == "expense" ? allocation : nil
        do {
            if let existing {
                try await repository.update(
                    existing, name: name, icon: icon, color: color, defaultAllocation: chosen)
            } else {
                try await repository.create(
                    name: name, type: type, icon: icon, color: color, defaultAllocation: chosen)
            }
            saved = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
