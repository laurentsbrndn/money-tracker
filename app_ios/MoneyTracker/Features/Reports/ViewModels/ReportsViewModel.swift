import Observation
import SwiftUI

/// Lainnya → Laporan (APP_FLOWS Flow 8): per category, income sources, trend, comparison, and
/// unrecorded differences. Everything is computed on the device from the local database by
/// `DomainRules` (Report.swift), so it works offline; the server endpoint
/// `GET /v1/reports/trend` is not used by the app (API.md §5).
@Observable
@MainActor
final class ReportsViewModel {
    var kind = ReportKind.category
    var month = YearMonth(containing: UserClock.today())
    /// How many months the trend and unrecorded-difference reports span.
    var range = 6
    private(set) var inputs = ReportInputs()
    private(set) var loaded = false

    private let database: AppDatabase
    private let lookups: LookupStore
    private let premium: PremiumStatus

    init(container: AppContainer) {
        database = container.database
        lookups = container.lookups
        premium = container.premium
    }

    var isPremium: Bool { premium.isPremium }
    var today: CivilDate { UserClock.today() }
    var currentMonth: YearMonth { YearMonth(containing: today) }
    var oldestFreeMonth: YearMonth { currentMonth.adding(months: -2) }
    var canGoNext: Bool { month < currentMonth }

    /// A free user sees the current month and the two before it (BUSINESS_RULES §7).
    func canView(_ month: YearMonth) -> Bool { isPremium || month >= oldestFreeMonth }

    var kindLocked: Bool { kind.premiumOnly && !isPremium }
    var monthLocked: Bool { kind.usesMonth && !canView(month) }

    func previousMonth() { month = month.adding(months: -1) }
    func nextMonth() { if canGoNext { month = month.adding(months: 1) } }

    func observe() async {
        let database = self.database
        await concurrently([
            {
                await forEachValue(database.observeAccounts()) {
                    self.inputs.accounts = $0.map(\.domain)
                    self.loaded = true
                }
            },
            {
                await forEachValue(database.observeAllTransactions()) {
                    self.inputs.transactions = $0.map(\.domain)
                }
            },
            {
                await forEachValue(database.observeBudgetGoals()) {
                    self.inputs.goals = $0.map(\.domain)
                }
            },
        ])
    }

    // MARK: - Report data

    var categoryItems: [KeyedAmount] {
        DomainRules.expenseByCategory(
            inputs.transactions, month: month, asOf: DomainRules.reportAsOf(month, today: today))
    }

    var sourceItems: [KeyedAmount] {
        DomainRules.incomeBySource(
            inputs.transactions, month: month, asOf: DomainRules.reportAsOf(month, today: today))
    }

    var trend: [TrendMonth] {
        DomainRules.trendReport(
            accounts: inputs.accounts, transactions: inputs.transactions, goals: inputs.goals,
            last: currentMonth, months: range, today: today)
    }

    var comparison: MonthComparison {
        DomainRules.compareMonths(
            accounts: inputs.accounts, transactions: inputs.transactions, goals: inputs.goals,
            month: month, today: today)
    }

    func categoryName(_ id: String?) -> String {
        id.flatMap { lookups.categories[$0]?.name } ?? String(localized: "Tanpa kategori")
    }

    func categoryColor(_ id: String?) -> Color? {
        id.flatMap { lookups.categories[$0] }.map { CategoryIcons.color($0.color) }
    }

    // MARK: - Slices

    /// Top entries stay; the rest is summed into "Lainnya".
    private static let maxSlices = 7

    func categoryEntries() -> [PieEntry] {
        let entries = categoryItems.enumerated().map { index, item in
            let category = item.key.flatMap { lookups.categories[$0] }
            return PieEntry(
                id: index, label: categoryName(item.key), amount: item.amount,
                color: categoryColor(item.key) ?? ChartColors.neutral,
                // "Tanpa kategori" cannot be filtered on, so it has nothing to open.
                filter: category.map {
                    TransactionFilter(
                        type: "expense", categoryId: $0.id, from: month.first, to: month.last)
                })
        }
        return withRest(entries)
    }

    func sourceEntries() -> [PieEntry] {
        let palette = CategoryIcons.palette
        let entries = sourceItems.enumerated().map { index, item in
            PieEntry(
                id: index, label: item.key ?? String(localized: "Tanpa sumber"),
                amount: item.amount,
                color: item.key == nil
                    ? ChartColors.neutral : CategoryIcons.color(palette[index % palette.count]),
                filter: item.key.map {
                    TransactionFilter(
                        type: "income", from: month.first, to: month.last, query: $0)
                })
        }
        return withRest(entries)
    }

    private func withRest(_ entries: [PieEntry]) -> [PieEntry] {
        guard entries.count > Self.maxSlices else { return entries }
        let rest = entries.dropFirst(Self.maxSlices).reduce(Int64(0)) { $0 + $1.amount }
        return Array(entries.prefix(Self.maxSlices))
            + [
                PieEntry(
                    id: Self.maxSlices, label: String(localized: "Lainnya"), amount: rest,
                    color: ChartColors.neutral, filter: nil)
            ]
    }

    func monthFilter(_ month: YearMonth, type: String? = nil) -> TransactionFilter {
        TransactionFilter(type: type, from: month.first, to: month.last)
    }
}
