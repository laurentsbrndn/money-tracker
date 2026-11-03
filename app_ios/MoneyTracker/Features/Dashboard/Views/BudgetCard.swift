import SwiftUI

/// The budget card of the dashboard (APP_FLOWS Flow 2 step 5): needs/wants/savings bars with goal
/// against actual, and what is not yet allocated. Wants turns red when it passes its goal.
struct BudgetCard: View {
    let month: MonthBudget
    let hidden: Bool
    var onTap: (() -> Void)?

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Budget").font(.headline)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if month.goal == nil {
                Text("Goal budget belum diatur").font(.subheadline.weight(.semibold))
                Text("Atur pembagian needs, wants, dan savings untuk melihat budget bulan ini.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                ForEach(Allocation.all, id: \.self) { allocation in
                    BudgetAllocationRow(
                        allocation: allocation, goalPct: month.pct(of: allocation),
                        result: month.result(of: allocation), hidden: hidden, compact: true)
                }
                HStack {
                    Text("Belum teralokasi").font(.subheadline)
                    Spacer()
                    AmountText(amount: month.budget.unallocated, hidden: hidden)
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))

        if let onTap {
            Button(action: onTap) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}
