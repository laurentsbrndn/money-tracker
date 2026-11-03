/// Entity names on the wire (SYNC_PROTOCOL §2).
enum SyncEntities {
    static let userSettings = "user_settings"
    static let categories = "categories"
    static let accounts = "accounts"
    static let balanceSnapshots = "balance_snapshots"
    static let transactions = "transactions"
    static let recurringRules = "recurring_rules"
    static let budgetGoals = "budget_goals"

    static let all = [
        userSettings, categories, accounts, balanceSnapshots, transactions, recurringRules,
        budgetGoals,
    ]
}
