import SwiftUI

/// Income, expense, and surplus of the selected month (APP_FLOWS Flow 2, step 2).
struct SummaryCard: View {
    let summary: MonthlySummary
    let hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                column("Pemasukan", summary.income, .income)
                Spacer()
                column("Pengeluaran", summary.expense, .expense)
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.surplus >= 0 ? "Surplus" : "Defisit")
                    .font(.subheadline).foregroundStyle(.secondary)
                AmountText(amount: summary.surplus, hidden: hidden)
                    .font(.title2.bold())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func column(_ title: LocalizedStringKey, _ amount: Int64, _ kind: AmountKind)
        -> some View
    {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            AmountText(amount: amount, kind: kind, hidden: hidden).font(.headline)
        }
    }
}
