import Foundation

// Plain value types for the formulas in BUSINESS_RULES.md. Ported from
// backend/internal/domainrules/types.go: no I/O, no GRDB. IDs are opaque strings and
// soft-deleted rows are flagged with `isDeleted`; deleted rows never count.

/// `accounts.type`.
enum AccountType: String, Sendable {
    case bank
    case eWallet = "e_wallet"
    case cash
    case savings
}

/// `transactions.type`.
enum TransactionType: String, Sendable {
    case income
    case expense
    case transfer
    case adjustment
}

/// `transactions.status`.
enum TransactionStatus: String, Sendable {
    case posted
    case pendingConfirmation = "pending_confirmation"
}

/// The needs/wants/savings bucket of an expense.
enum Allocation: String, Sendable {
    case needs
    case wants
    case savings
}

/// A calendar month (`YYYY-MM`), the reporting period.
struct YearMonth: Hashable, Comparable, Sendable {
    var year: Int
    var month: Int

    static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

struct Account: Sendable {
    var id: String
    var type: AccountType
    var openingBalance: Int64
    var openingDate: CivilDate
    var includeInTotal: Bool
    var isDeleted: Bool
}

/// `toAccountID` is nil unless `type` is `.transfer`; `allocation` is nil unless `type` is
/// `.expense`. `amount` is signed for `.adjustment` and positive otherwise.
struct Transaction: Sendable {
    var id: String
    var type: TransactionType
    var status: TransactionStatus
    var date: CivilDate
    var amount: Int64
    var accountID: String
    var toAccountID: String?
    var allocation: Allocation?
    var isDeleted: Bool
}

/// The real balance a user observed on a date.
struct BalanceSnapshot: Sendable {
    var accountID: String
    var date: CivilDate
    var amount: Int64
    var updatedAt: Date
    var isDeleted: Bool
}

/// The needs/wants/savings split effective from a month.
struct BudgetGoal: Sendable {
    var effectiveMonth: YearMonth
    var needsPct: Int64
    var wantsPct: Int64
    var savingsPct: Int64
    var plannedIncome: Int64?
    var isDeleted: Bool
}
