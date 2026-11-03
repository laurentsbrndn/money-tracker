import SwiftUI

/// "Rincian {name}": the categories behind one bucket (APP_FLOWS Flow 6 step 2).
struct BudgetBreakdownSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    let allocation: Allocation
    let month: YearMonth
    let breakdown: AllocationBreakdown

    private var hidden: Bool { container.preferences.hideAmounts }

    var body: some View {
        NavigationStack {
            List {
                if breakdown.categories.isEmpty && breakdown.transferNet == 0 {
                    Text("Belum ada transaksi di alokasi ini bulan ini.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(breakdown.categories, id: \.categoryID) { total in
                            categoryRow(total)
                        }
                        if breakdown.transferNet != 0 {
                            HStack {
                                Text("Transfer ke tabungan (bersih)")
                                Spacer()
                                AmountText(amount: breakdown.transferNet, hidden: hidden)
                            }
                        }
                    }
                    Section {
                        HStack {
                            Text("Total").font(.headline)
                            Spacer()
                            AmountText(amount: breakdown.total, hidden: hidden).font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Rincian \(allocation.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Selesai") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func categoryRow(_ total: CategoryTotal) -> some View {
        let category = total.categoryID.flatMap { container.lookups.categories[$0] }
        return HStack {
            if let category {
                Label {
                    Text(category.name)
                } icon: {
                    Image(systemName: CategoryIcons.symbol(category.icon))
                        .foregroundStyle(CategoryIcons.color(category.color))
                }
            } else {
                Text("Tanpa kategori")
            }
            Spacer()
            AmountText(amount: total.amount, hidden: hidden)
        }
    }
}
