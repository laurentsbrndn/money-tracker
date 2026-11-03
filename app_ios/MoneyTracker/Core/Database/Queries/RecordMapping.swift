/// Records → the pure value types of `Core/DomainRules`, so formulas never see GRDB.
extension AccountRecord {
    var domain: Account {
        Account(
            id: id, type: AccountType(rawValue: type) ?? .bank, openingBalance: openingBalance,
            openingDate: openingDate, includeInTotal: includeInTotal, isDeleted: deletedAt != nil)
    }
}

extension TransactionRecord {
    var domain: Transaction {
        Transaction(
            id: id, type: TransactionType(rawValue: type) ?? .expense,
            status: TransactionStatus(rawValue: status) ?? .posted, date: transactionDate,
            amount: amount, accountID: accountId, toAccountID: toAccountId,
            allocation: allocation.flatMap(Allocation.init(rawValue:)), isDeleted: deletedAt != nil)
    }
}
