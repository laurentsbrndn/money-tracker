import Observation

/// The three-step setup wizard for new users (APP_FLOWS Flow 1, step 6): Cash balance, extra
/// accounts, hidden categories. Budget goal, reminders, and app lock belong to Fase 2 and are not
/// part of this wizard yet. It can be skipped at any time.
@Observable
@MainActor
final class SetupWizardViewModel {
    static let stepCount = 3

    var step = 0
    var cashText = ""
    private(set) var busy = false
    var errorMessage: String?

    private let setup: SetupRepository
    private let accounts: AccountsRepository
    private let categories: CategoriesRepository

    init(container: AppContainer) {
        setup = container.setup
        accounts = container.accounts
        categories = container.categories
    }

    var isLastStep: Bool { step == Self.stepCount - 1 }

    func next() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            if step == 0, let balance = MoneyFormatter.value(of: cashText) {
                try await saveCashBalance(balance)
            }
            if isLastStep {
                try await setup.markDone()
            } else {
                step += 1
            }
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func back() {
        if step > 0 { step -= 1 }
    }

    func skipAll() async {
        do { try await setup.markDone() } catch { errorMessage = ErrorMessages.describe(error) }
    }

    func setHidden(_ category: CategoryRecord, hidden: Bool) async {
        do {
            try await categories.setHidden(category, hidden: hidden)
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    /// Sets the Cash account's balance (its opening balance and first snapshot). Does nothing when
    /// the Cash account is missing or unchanged.
    private func saveCashBalance(_ balance: Int64) async throws {
        guard let cash = try await setup.findCash(), cash.openingBalance != balance else { return }
        try await accounts.update(
            cash, name: cash.name, type: cash.type, openingBalance: balance,
            openingDate: cash.openingDate, providerKey: cash.providerKey,
            includeInTotal: cash.includeInTotal)
    }
}
