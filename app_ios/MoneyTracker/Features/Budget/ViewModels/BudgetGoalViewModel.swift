import Observation

/// The "Atur goal budget" form (APP_FLOWS Flow 6 step 1): three percentages that add up to 100
/// and an optional planned income, effective from the current month.
@Observable
@MainActor
final class BudgetGoalViewModel {
    var needsText = ""
    var wantsText = ""
    var savingsText = ""
    var plannedIncomeText = ""
    var errorMessage: String?
    private(set) var busy = false
    private(set) var loaded = false

    private let database: AppDatabase
    private let repository: BudgetRepository

    init(container: AppContainer) {
        database = container.database
        repository = container.budget
    }

    /// The month the goal applies from.
    var month: YearMonth { YearMonth(containing: UserClock.today()) }

    var input: BudgetGoalInput {
        BudgetGoalInput(
            needs: Int(needsText) ?? 0, wants: Int(wantsText) ?? 0, savings: Int(savingsText) ?? 0,
            plannedIncome: MoneyFormatter.value(of: plannedIncomeText))
    }

    var total: Int { input.total }
    var isValid: Bool { input.isValid }

    func apply(_ preset: (needs: Int, wants: Int, savings: Int)) {
        needsText = String(preset.needs)
        wantsText = String(preset.wants)
        savingsText = String(preset.savings)
    }

    /// Fills the form with the goal in force this month (or 50/30/20 when there is none).
    func load() async {
        let rows = (try? await database.pool.read { try $0.liveBudgetGoals() }) ?? []
        let goal = DomainRules.effectiveGoal(rows.map(\.domain), month: month)
        let initial =
            goal.map {
                BudgetGoalInput(
                    needs: Int($0.needsPct), wants: Int($0.wantsPct), savings: Int($0.savingsPct),
                    plannedIncome: $0.plannedIncome)
            } ?? .standard
        needsText = String(initial.needs)
        wantsText = String(initial.wants)
        savingsText = String(initial.savings)
        plannedIncomeText =
            initial.plannedIncome.map { MoneyFormatter.formatInput(String($0)) } ?? ""
        loaded = true
    }

    /// Saves the goal; returns whether the form can close.
    func save() async -> Bool {
        busy = true
        errorMessage = nil
        defer { busy = false }
        do {
            try await repository.saveGoal(month: month, input: input)
            return true
        } catch {
            errorMessage = ErrorMessages.describe(error)
            return false
        }
    }
}
