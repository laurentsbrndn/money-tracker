import Observation

@Observable
@MainActor
final class ProfileViewModel {
    var name: String
    private(set) var busy = false
    var notice: String?
    var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
        name = container.session.user?.name ?? ""
    }

    var user: SessionUser? { container.session.user }

    func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = ValidationError.nameRequired.errorDescription
            return
        }
        busy = true
        defer { busy = false }
        do {
            container.session.updateUser(
                try await container.settings.updateName(String(trimmed.prefix(100))))
            notice = String(localized: "Profil disimpan")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
