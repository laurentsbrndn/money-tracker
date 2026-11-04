import SwiftUI

/// One measure of the comparison: this month, last month, and what changed.
struct ReportChangeRow: View {
    let label: String
    let current: Int64
    let previous: Int64
    let hidden: Bool
    /// More expense is bad; more of anything else is good.
    let higherIsBad: Bool

    var body: some View {
        let change = current - previous
        let bad = higherIsBad ? change > 0 : change < 0
        let color = bad ? ChartColors.expense : ChartColors.income
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(
                    "\(MoneyFormatter.rupiah(current, hidden: hidden))  ←  \(MoneyFormatter.rupiah(previous, hidden: hidden))"
                ).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if change != 0 {
                Label(
                    MoneyFormatter.rupiah(abs(change), hidden: hidden),
                    systemImage: change > 0 ? "arrow.up" : "arrow.down"
                )
                .font(.callout).foregroundStyle(color)
            }
        }
        .padding(.vertical, 2)
    }
}
