import Observation

/// The entry form (APP_FLOWS Flow 3): expense, income, transfer with an optional admin fee; also
/// edits an existing transaction. Validation lives in `TransactionsRepository.save`.
@Observable
@MainActor
final class TransactionFormViewModel {
    /// 999.999.999.999 has 12 digits (BUSINESS_RULES §6).
    private static let maxDigits = 12

    let mode: TransactionFormRequest.Mode

    var type = "expense"
    private(set) var digits = ""
    var accountId: String?
    var toAccountId: String?
    var categoryId: String?
    var allocation: String?
    var date = UserClock.today()
    var note = ""
    var source = ""
    var feeText = ""
    private(set) var sourceSuggestions: [String] = []
    private(set) var loaded = false
    private(set) var busy = false
    private(set) var saved = false
    private(set) var shouldClose = false
    var errorMessage: String?

    private var existing: TransactionRecord?
    private let repository: TransactionsRepository
    private let lookups: LookupStore

    init(container: AppContainer, mode: TransactionFormRequest.Mode) {
        self.mode = mode
        repository = container.transactions
        lookups = container.lookups
        if case .new(let initialType, let fromAccountId, let amount) = mode {
            type =
                ["expense", "income", "transfer"].contains(initialType) ? initialType : "expense"
            accountId = fromAccountId
            if let amount, amount > 0 { digits = String(amount) }
        }
    }

    var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var amount: Int64? { digits.isEmpty ? nil : Int64(digits) }

    /// Accounts the user can pick: not archived, plus the ones the edited transaction already uses.
    var selectableAccounts: [AccountRecord] {
        let used: Set<String> = Set([existing?.accountId, existing?.toAccountId].compactMap { $0 })
        return lookups.accounts.values
            .filter { $0.deletedAt == nil && ($0.archivedAt == nil || used.contains($0.id)) }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    /// Categories of the current type that are shown in forms (hidden and archived ones only when
    /// already chosen).
    var visibleCategories: [CategoryRecord] {
        lookups.categories.values
            .filter {
                $0.deletedAt == nil && $0.type == type
                    && ((!$0.isHidden && $0.archivedAt == nil) || $0.id == categoryId)
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The destination is a savings account and the source is not: counts as savings this month
    /// (BUSINESS_RULES §4.5).
    var transfersToSavings: Bool {
        let accounts = lookups.accounts
        guard let toAccountId, let to = accounts[toAccountId] else { return false }
        let from = accountId.flatMap { accounts[$0] }
        return to.type == "savings" && from?.type != "savings"
    }

    func prepare() async {
        sourceSuggestions = (try? await repository.recentSources()) ?? []
        if case .edit(let id) = mode {
            guard let row = try? await repository.find(id), row.deletedAt == nil,
                row.type != "adjustment"
            else {
                shouldClose = true
                return
            }
            let fees =
                row.type == "transfer" ? ((try? await repository.fees(of: row.id)) ?? []) : []
            existing = row
            type = row.type
            digits = String(row.amount)
            accountId = row.accountId
            toAccountId = row.toAccountId
            categoryId = row.categoryId
            allocation = row.allocation
            date = row.transactionDate
            note = row.note ?? ""
            source = row.source ?? ""
            if let fee = fees.first {
                feeText = MoneyFormatter.formatInput(String(fee.amount))
            }
        } else {
            await applyDefaultAccount()
        }
        loaded = true
    }

    /// Keeps a valid account; otherwise the one used last for this type, else the first
    /// (APP_FLOWS Flow 3).
    func applyDefaultAccount() async {
        let open = selectableAccounts
        if let accountId, open.contains(where: { $0.id == accountId }) { return }
        let last = try? await repository.lastAccountId(type: type)
        accountId = open.first { $0.id == last }?.id ?? open.first?.id
    }

    /// "Jadikan berulang" (APP_FLOWS Flow 10): the fields typed so far become the template of a
    /// recurring rule, and the date its first occurrence.
    func recurringPrefill() -> RecurringPrefill {
        RecurringPrefill(
            type: type, startDate: date, amount: amount, accountId: accountId,
            toAccountId: type == "transfer" ? toAccountId : nil,
            categoryId: type == "transfer" ? nil : categoryId,
            allocation: type == "expense" ? allocation : nil,
            source: type == "income" ? source : nil, note: note)
    }

    func typeChanged() {
        categoryId = nil
        allocation = nil
        toAccountId = nil
        Task { await applyDefaultAccount() }
    }

    func selectCategory(_ category: CategoryRecord) {
        categoryId = category.id
        if type == "expense" { allocation = category.defaultAllocation ?? allocation }
    }

    func addDigits(_ added: String) {
        // No leading zeros: typing 0 on an empty amount stays empty.
        var next = digits + added
        while next.hasPrefix("0") { next.removeFirst() }
        guard next.count <= Self.maxDigits else { return }
        digits = next
    }

    func backspace() {
        if !digits.isEmpty { digits.removeLast() }
    }

    func clearAmount() {
        digits = ""
    }

    func save() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        let draft = TransactionDraft(
            type: type, amount: amount, accountId: accountId,
            toAccountId: type == "transfer" ? toAccountId : nil,
            categoryId: type == "transfer" ? nil : categoryId,
            allocation: type == "expense" ? allocation : nil,
            source: type == "income" ? source : nil,
            note: note, date: date,
            fee: type == "transfer" ? MoneyFormatter.value(of: feeText) : nil, existing: existing)
        do {
            try await repository.save(draft)
            saved = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
