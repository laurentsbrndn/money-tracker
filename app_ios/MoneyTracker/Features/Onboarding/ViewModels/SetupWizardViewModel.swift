import Observation

/// The six-step setup wizard for new users (APP_FLOWS Flow 1, step 6): Cash balance, extra
/// accounts, budget goal, hidden categories, notifications, and app lock. It can be skipped at
/// any time.
@Observable
@MainActor
final class SetupWizardViewModel {
    static let stepCount = 6

    static let cashStep = 0
    static let goalStep = 2
    static let notificationStep = 4

    var step = 0
    var cashText = ""
    private(set) var busy = false
    var errorMessage: String?

    /// The goal form of step 3 (starts from the 50/30/20 the server seeded).
    let goal: BudgetGoalViewModel
    var reminderEnabled = false
    var reminderDate = NotificationSettingsViewModel.date(
        from: NotificationSettingsViewModel.defaultReminderTime)
    let lock: AppLockController

    private let setup: SetupRepository
    private let accounts: AccountsRepository
    private let categories: CategoriesRepository
    private let userSettings: UserSettingsRepository
    private let notificationService: NotificationService

    init(container: AppContainer) {
        goal = BudgetGoalViewModel(container: container)
        lock = container.lock
        userSettings = container.userSettings
        notificationService = container.notificationService
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
            switch step {
            case Self.cashStep:
                if let balance = MoneyFormatter.value(of: cashText) {
                    try await saveCashBalance(balance)
                }
            case Self.goalStep:
                // Nothing is written when it equals the goal already in force this month.
                if goal.loaded, !(await goal.save()) {
                    errorMessage = goal.errorMessage
                    return
                }
            case Self.notificationStep:
                try await saveReminder()
            default:
                break
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

    /// Step 5: turns the daily reminder on at the chosen time, asking for the notification
    /// permission now, the moment the user opts in. Nothing happens when it stays off.
    private func saveReminder() async throws {
        guard reminderEnabled else { return }
        if await notificationService.isUndetermined() {
            await notificationService.requestPermission()
        }
        try await userSettings.setDailyReminderTime(
            NotificationSettingsViewModel.time(from: reminderDate))
    }

    func setBiometric(_ enabled: Bool) async {
        let ok = await lock.setBiometric(
            enabled: enabled, reason: String(localized: "Aktifkan buka kunci dengan biometrik"))
        if !ok && enabled { errorMessage = String(localized: "Biometrik tidak bisa diaktifkan.") }
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
