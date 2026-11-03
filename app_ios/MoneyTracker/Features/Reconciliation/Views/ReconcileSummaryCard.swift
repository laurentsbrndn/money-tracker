import SwiftUI

/// Step 5 of Flow 5: how many reconciled accounts match and what was adjusted.
struct ReconcileSummaryCard: View {
    let matched: Int
    let total: Int
    let adjustedTotal: Int64
    let hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ringkasan").font(.headline)
            Text("\(matched) dari \(total) akun cocok")
            if adjustedTotal != 0 {
                Text(
                    "Total disesuaikan: \(MoneyFormatter.signedRupiah(adjustedTotal, hidden: hidden))"
                )
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
