import Foundation

/// A sum for one key of a breakdown (`key` is nil for "no category" or "no source").
struct KeyedAmount: Sendable, Equatable {
    var key: String?
    var amount: Int64
}

/// One month of the trend report (BUSINESS_RULES §4.6).
struct TrendMonth: Sendable, Equatable {
    var month: YearMonth
    var income: Int64
    var expense: Int64
    var surplus: Int64
    /// `savings(M)` of §4.5.
    var savings: Int64
    /// Signed sum of the month's adjustments.
    var adjustments: Int64
}

/// One line of the comparison between a month and the one before it.
struct MonthComparisonLine: Sendable, Equatable {
    /// A category id; nil is "no category".
    var key: String?
    var current: Int64
    var previous: Int64

    var change: Int64 { current - previous }
}

/// This month against the month before (§4.6 "perbandingan").
struct MonthComparison: Sendable, Equatable {
    var month: YearMonth
    var current: TrendMonth
    var previous: TrendMonth
    /// Per expense category, largest current amount first.
    var expenseByCategory: [MonthComparisonLine]
}

/// Port of `core/domain_rules/report.dart` (BUSINESS_RULES §4.6). Pure Swift, no I/O.
extension DomainRules {
    /// The last day a month's figures cover: its last day, or `today` while the month is not
    /// over. Months after the current one are read as of today, so they stay empty.
    static func reportAsOf(_ month: YearMonth, today: CivilDate) -> CivilDate {
        month.last < today ? month.last : today
    }

    /// The month's expenses per category, largest first.
    static func expenseByCategory(
        _ txs: [Transaction], month: YearMonth, asOf: CivilDate
    ) -> [KeyedAmount] {
        sumBy(txs, month: month, asOf: asOf, type: .expense) { $0.categoryID }
    }

    /// The month's income per category, largest first.
    static func incomeByCategory(
        _ txs: [Transaction], month: YearMonth, asOf: CivilDate
    ) -> [KeyedAmount] {
        sumBy(txs, month: month, asOf: asOf, type: .income) { $0.categoryID }
    }

    /// The month's income per `source`, largest first. An income without a source (or a blank
    /// one) is grouped under nil; sources that differ only in case or surrounding spaces are one.
    static func incomeBySource(
        _ txs: [Transaction], month: YearMonth, asOf: CivilDate
    ) -> [KeyedAmount] {
        var totals: [String: Int64] = [:]
        var labels: [String: String] = [:]
        var none: Int64 = 0
        for tx in txs where counts(tx, asOf: asOf) && month.contains(tx.date) && tx.type == .income
        {
            let label = (tx.source ?? "").trimmingCharacters(in: .whitespaces)
            if label.isEmpty {
                none += tx.amount
                continue
            }
            let key = label.lowercased()
            if labels[key] == nil { labels[key] = label }
            totals[key, default: 0] += tx.amount
        }
        var items = totals.map { KeyedAmount(key: labels[$0.key], amount: $0.value) }
        if none != 0 { items.append(KeyedAmount(key: nil, amount: none)) }
        return sorted(items)
    }

    private static func sumBy(
        _ txs: [Transaction], month: YearMonth, asOf: CivilDate, type: TransactionType,
        keyOf: (Transaction) -> String?
    ) -> [KeyedAmount] {
        // A dictionary cannot hold a nil key, so "no key" is summed on the side.
        var totals: [String: Int64] = [:]
        var none: Int64 = 0
        var hasNone = false
        for tx in txs where counts(tx, asOf: asOf) && month.contains(tx.date) && tx.type == type {
            if let key = keyOf(tx) {
                totals[key, default: 0] += tx.amount
            } else {
                none += tx.amount
                hasNone = true
            }
        }
        var items = totals.map { KeyedAmount(key: $0.key, amount: $0.value) }
        if hasNone { items.append(KeyedAmount(key: nil, amount: none)) }
        return sorted(items)
    }

    /// Largest amount first; ties by key so the order is stable.
    private static func sorted(_ items: [KeyedAmount]) -> [KeyedAmount] {
        items.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            return ($0.key ?? "") < ($1.key ?? "")
        }
    }

    /// The signed sum of the month's adjustments: the differences the user did not record.
    static func unrecordedDifference(
        _ txs: [Transaction], month: YearMonth, asOf: CivilDate
    ) -> Int64 {
        var total: Int64 = 0
        for tx in txs
        where counts(tx, asOf: asOf) && month.contains(tx.date) && tx.type == .adjustment {
            total += tx.amount
        }
        return total
    }

    /// Income, expense, surplus, savings, and unrecorded differences of the `months` months that
    /// end with `last`, oldest first. Every month is figured as of its own last day (or `today`
    /// for the current month), like the server's `GET /v1/reports/trend`.
    static func trendReport(
        accounts: [Account], transactions: [Transaction], goals: [BudgetGoal], last: YearMonth,
        months: Int, today: CivilDate
    ) -> [TrendMonth] {
        var result: [TrendMonth] = []
        for back in stride(from: months - 1, through: 0, by: -1) {
            let month = last.adding(months: -back)
            let asOf = reportAsOf(month, today: today)
            let summary = computeMonthlySummary(
                accounts: accounts, transactions: transactions, month: month, asOf: asOf)
            let budget = computeBudget(
                accounts: accounts, transactions: transactions,
                goal: effectiveGoal(goals, month: month), month: month, asOf: asOf)
            result.append(
                TrendMonth(
                    month: month, income: summary.income, expense: summary.expense,
                    surplus: summary.surplus, savings: budget.savings.actual,
                    adjustments: unrecordedDifference(transactions, month: month, asOf: asOf)))
        }
        return result
    }

    /// The figures of `month` next to those of the month before it. The previous month is
    /// figured as of its last day, the current one as of `today`.
    static func compareMonths(
        accounts: [Account], transactions: [Transaction], goals: [BudgetGoal], month: YearMonth,
        today: CivilDate
    ) -> MonthComparison {
        let pair = trendReport(
            accounts: accounts, transactions: transactions, goals: goals, last: month, months: 2,
            today: today)
        let before = month.adding(months: -1)
        let now = Dictionary(
            expenseByCategory(transactions, month: month, asOf: reportAsOf(month, today: today))
                .map { ($0.key ?? Self.noKey, $0.amount) }, uniquingKeysWith: +)
        let prior = Dictionary(
            expenseByCategory(transactions, month: before, asOf: reportAsOf(before, today: today))
                .map { ($0.key ?? Self.noKey, $0.amount) }, uniquingKeysWith: +)
        var keys = Set(now.keys)
        keys.formUnion(prior.keys)
        let lines = keys.map {
            MonthComparisonLine(
                key: $0 == Self.noKey ? nil : $0, current: now[$0] ?? 0, previous: prior[$0] ?? 0)
        }.sorted {
            if $0.current != $1.current { return $0.current > $1.current }
            if $0.previous != $1.previous { return $0.previous > $1.previous }
            return ($0.key ?? "") < ($1.key ?? "")
        }
        return MonthComparison(
            month: month, current: pair[1], previous: pair[0], expenseByCategory: lines)
    }

    /// Stands for the nil key inside dictionaries; a real id is a UUID and never equals it.
    private static let noKey = ""
}
