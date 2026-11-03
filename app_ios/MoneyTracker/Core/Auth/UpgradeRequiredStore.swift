import Observation

/// Set when the server answers `426 upgrade_required` (API.md §1.1): nothing else is usable
/// until the app is updated.
@Observable
@MainActor
final class UpgradeRequiredStore {
    private(set) var isRequired = false

    func flag() {
        isRequired = true
    }
}
