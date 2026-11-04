import Observation

/// Lainnya → Transaksi berulang (APP_FLOWS Flow 10): the rules, whether each one runs, and the
/// way to pause, resume, or open one.
@Observable
@MainActor
final class RecurringViewModel {
    private(set) var rules: [RecurringRuleRecord] = []
    private(set) var loaded = false
    var errorMessage: String?
    /// Resuming without premium: the screen offers the paywall.
    var needsPremium = false

    private let repository: RecurringRepository

    init(container: AppContainer) {
        repository = container.recurring
    }

    func observe() async {
        await forEachValue(repository.observeAll()) {
            self.rules = $0
            self.loaded = true
        }
    }

    func togglePause(_ rule: RecurringRuleRecord) async {
        do {
            try await repository.setPaused(rule, paused: !rule.isPaused)
        } catch is PlanLimitError {
            needsPremium = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
