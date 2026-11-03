/// Income/expense summary of one month (§4.1).
struct MonthlySummary: Sendable, Equatable {
    var income: Int64
    var expense: Int64
    var surplus: Int64
    /// Expected total on the last day of the previous month.
    var openingTotal: Int64
}

extension DomainRules {
    /// Whether `tx` takes part in any formula as of `asOf` (§3): not deleted, posted, and dated
    /// on or before `asOf`.
    static func counts(_ tx: Transaction, asOf: CivilDate) -> Bool {
        !tx.isDeleted && tx.status == .posted && tx.date <= asOf
    }

    /// E(A, d): the opening balance plus every counted transaction of the account dated within
    /// [opening_date, d] (§4.2).
    static func expectedBalance(
        account: Account, transactions: [Transaction], on date: CivilDate
    ) -> Int64 {
        var balance = account.openingBalance
        for tx in transactions {
            guard counts(tx, asOf: date), tx.date >= account.openingDate else { continue }
            switch tx.type {
            case .income:
                if tx.accountID == account.id { balance += tx.amount }
            case .expense:
                if tx.accountID == account.id { balance -= tx.amount }
            case .transfer:
                if tx.accountID == account.id { balance -= tx.amount }
                if tx.toAccountID == account.id { balance += tx.amount }
            case .adjustment:
                if tx.accountID == account.id { balance += tx.amount }
            }
        }
        return balance
    }

    /// Whether the account is part of totals: included and not deleted. Archived accounts still
    /// count.
    static func isInTotal(_ account: Account) -> Bool {
        account.includeInTotal && !account.isDeleted
    }

    /// Sum of E(A, d) over the accounts that are part of the total.
    static func expectedTotal(
        accounts: [Account], transactions: [Transaction], on date: CivilDate
    ) -> Int64 {
        var total: Int64 = 0
        for account in accounts where isInTotal(account) {
            total += expectedBalance(account: account, transactions: transactions, on: date)
        }
        return total
    }

    /// §4.1. Transfers and adjustments are neither income nor expense.
    static func computeMonthlySummary(
        accounts: [Account], transactions: [Transaction], month: YearMonth, asOf: CivilDate
    ) -> MonthlySummary {
        var income: Int64 = 0
        var expense: Int64 = 0
        for tx in transactions where counts(tx, asOf: asOf) && month.contains(tx.date) {
            switch tx.type {
            case .income: income += tx.amount
            case .expense: expense += tx.amount
            case .transfer, .adjustment: break
            }
        }
        return MonthlySummary(
            income: income,
            expense: expense,
            surplus: income - expense,
            openingTotal: expectedTotal(
                accounts: accounts, transactions: transactions,
                on: month.adding(months: -1).last))
    }
}
