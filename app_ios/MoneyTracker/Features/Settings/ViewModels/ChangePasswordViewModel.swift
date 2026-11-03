import Observation

@Observable
@MainActor
final class ChangePasswordViewModel {
    var current = ""
    var new = ""
    private(set) var currentError: String?
    private(set) var newError: String?
    private(set) var busy = false
    private(set) var done = false
    var errorMessage: String?

    private let repository: SettingsRepository

    init(container: AppContainer) {
        repository = container.settings
    }

    func save() async {
        currentError = AuthValidators.required(current)
        newError = AuthValidators.password(new)
        guard currentError == nil, newError == nil else { return }
        busy = true
        defer { busy = false }
        do {
            try await repository.changePassword(current: current, new: new)
            done = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
