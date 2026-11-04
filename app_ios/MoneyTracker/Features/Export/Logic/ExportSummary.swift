/// Totals printed at the top of the PDF. Transfers and adjustments are not income or expense
/// (BUSINESS_RULES), so they only count in `count`.
struct ExportSummary: Sendable, Equatable {
    var income: Int64
    var expense: Int64
    var count: Int

    init(of rows: [ExportRow]) {
        var income: Int64 = 0
        var expense: Int64 = 0
        for row in rows {
            if row.type == .income {
                income += row.amount
            } else if row.type == .expense {
                expense += row.amount
            }
        }
        self.income = income
        self.expense = expense
        count = rows.count
    }

    var difference: Int64 { income - expense }
}
