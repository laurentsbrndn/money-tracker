import Observation

/// Create or edit a recurring rule (APP_FLOWS Flow 10). With `ruleId` it edits that rule; with
/// `prefill` a new rule starts from a transaction.
@Observable
@MainActor
final class RecurringFormViewModel {
    var type = "expense"
    var amountText = ""
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var note = ""
    var source = ""
    var frequency = RecurringFrequency.monthly
    var intervalText = "1"
    var dayOfWeek = 1
    var dayOfMonth = 1
    var monthOfYear = 1
    var startDate = UserClock.today() {
        didSet { if startDate != oldValue && !loadingExisting { applyScheduleDefaults() } }
    }
    var hasEnd = false
    var endDate = UserClock.today()
    var mode = "auto"
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var saved = false
    private(set) var deleted = false
    var errorMessage: String?
    /// The error was a plan limit: the screen offers the paywall.
    private(set) var planLimit = false

    let ruleId: String?
    private var existing: RecurringRuleRecord?
    private var loadingExisting = false
    private let repository: RecurringRepository
    private let lookups: LookupStore

    init(container: AppContainer, ruleId: String?, prefill: RecurringPrefill?) {
        self.ruleId = ruleId
        repository = container.recurring
        lookups = container.lookups
        if let prefill {
            type = prefill.type
            startDate = prefill.startDate
            accountId = prefill.accountId
            toAccountId = prefill.toAccountId
            categoryId = prefill.categoryId
            allocation = prefill.allocation
            note = prefill.note ?? ""
            source = prefill.source ?? ""
            if let amount = prefill.amount, amount > 0 {
                amountText = MoneyFormatter.formatInput(String(amount))
            }
        }
        applyScheduleDefaults()
    }

    var isEdit: Bool { ruleId != nil }

    /// The day fields start from the first occurrence's date.
    private func applyScheduleDefaults() {
        dayOfWeek = startDate.isoWeekday
        dayOfMonth = startDate.day
        monthOfYear = startDate.month
    }

    var selectableAccounts: [AccountRecord] {
        let used: Set<String> = Set([existing?.accountId, existing?.toAccountId].compactMap { $0 })
        return lookups.accounts.values
            .filter { $0.deletedAt == nil && ($0.archivedAt == nil || used.contains($0.id)) }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    var visibleCategories: [CategoryRecord] {
        lookups.categories.values
            .filter {
                $0.deletedAt == nil && $0.type == type
                    && ((!$0.isHidden && $0.archivedAt == nil) || $0.id == categoryId)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func load() async {
        guard !loaded else { return }
        if let ruleId {
            guard let row = try? await repository.find(ruleId), row.deletedAt == nil else {
                deleted = true
                return
            }
            loadingExisting = true
            existing = row
            type = row.type
            amountText = MoneyFormatter.formatInput(String(row.amount))
            accountId = row.accountId
            toAccountId = row.toAccountId
            categoryId = row.categoryId
            allocation = row.allocation
            note = row.note ?? ""
            source = row.source ?? ""
            frequency = RecurringFrequency(rawValue: row.frequency) ?? .monthly
            intervalText = String(row.intervalCount)
            startDate = row.startDate
            dayOfWeek = row.dayOfWeek ?? row.startDate.isoWeekday
            dayOfMonth = row.dayOfMonth ?? row.startDate.day
            monthOfYear = row.monthOfYear ?? row.startDate.month
            hasEnd = row.endDate != nil
            endDate = row.endDate ?? row.startDate
            mode = row.mode
            loadingExisting = false
        } else if accountId == nil {
            accountId = selectableAccounts.first?.id
        }
        loaded = true
    }

    func typeChanged() {
        categoryId = nil
        allocation = nil
        toAccountId = nil
    }

    func selectCategory(_ category: CategoryRecord) {
        categoryId = category.id
        if type == "expense" { allocation = category.defaultAllocation ?? allocation }
    }

    func save() async {
        busy = true
        errorMessage = nil
        planLimit = false
        defer { busy = false }
        let input = RecurringRuleInput(
            type: type, amount: MoneyFormatter.value(of: amountText), accountId: accountId,
            toAccountId: type == "transfer" ? toAccountId : nil,
            categoryId: type == "transfer" ? nil : categoryId,
            allocation: type == "expense" ? allocation : nil,
            source: type == "income" ? source : nil, note: note, frequency: frequency,
            intervalCount: Int(intervalText) ?? 0, dayOfWeek: dayOfWeek, dayOfMonth: dayOfMonth,
            monthOfYear: monthOfYear, startDate: startDate, endDate: hasEnd ? endDate : nil,
            mode: mode)
        do {
            try await repository.save(input, existing: existing)
            saved = true
        } catch let error as PlanLimitError {
            planLimit = true
            errorMessage = error.errorDescription
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func delete() async {
        guard let existing else { return }
        busy = true
        defer { busy = false }
        do {
            try await repository.delete(existing.id)
            deleted = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
