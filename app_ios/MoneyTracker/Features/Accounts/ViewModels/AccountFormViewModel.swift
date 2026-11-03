import Observation

/// Create or edit an account (APP_FLOWS Flow 5).
@Observable
@MainActor
final class AccountFormViewModel {
    let accountId: String?

    var type = "bank"
    var providerKey: String?
    var name = ""
    var balanceText = ""
    var openingDate = UserClock.today()
    var includeInTotal = true
    private(set) var busy = false
    private(set) var saved = false
    var errorMessage: String?

    private var existing: AccountRecord?
    private let repository: AccountsRepository

    init(container: AppContainer, accountId: String?) {
        self.accountId = accountId
        repository = container.accounts
    }

    var isEditing: Bool { accountId != nil }

    func load() async {
        guard let accountId, existing == nil, let account = try? await repository.find(accountId)
        else { return }
        existing = account
        type = account.type
        providerKey = account.providerKey
        name = account.name
        balanceText = MoneyFormatter.formatInput(
            String(account.openingBalance), allowNegative: true)
        openingDate = account.openingDate
        includeInTotal = account.includeInTotal
    }

    func save() async {
        busy = true
        errorMessage = nil
        defer { busy = false }
        let balance = MoneyFormatter.value(of: balanceText, allowNegative: true) ?? 0
        let provider = type == "cash" ? nil : providerKey
        do {
            if let existing {
                try await repository.update(
                    existing, name: name, type: type, openingBalance: balance,
                    openingDate: openingDate, providerKey: provider, includeInTotal: includeInTotal)
            } else {
                try await repository.create(
                    name: name, type: type, openingBalance: balance, openingDate: openingDate,
                    providerKey: provider, includeInTotal: includeInTotal)
            }
            saved = true
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
