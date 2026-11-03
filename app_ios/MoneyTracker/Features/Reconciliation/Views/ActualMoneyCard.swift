import SwiftUI

/// The "Uang aktual" card (APP_FLOWS Flow 2 step 3): real balances of banks and e-wallets, cash,
/// their total, and when they were last updated. Tapping it opens the Accounts tab.
struct ActualMoneyCard: View {
    let overview: ReconcileOverview
    let hidden: Bool
    var onTap: (() -> Void)?

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Uang aktual").font(.headline)
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
                }
            }
            if overview.lastUpdated == nil {
                Text("Belum ada saldo asli. Cocokkan saldo untuk mengisinya.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                AmountText(amount: overview.totals.actualTotal, hidden: hidden)
                    .font(.title2.bold())
                HStack {
                    part("Rekening & e-wallet", overview.totals.actualAccounts)
                    Spacer()
                    part("Cash", overview.totals.actualCash)
                }
                if let updated = overview.lastUpdated {
                    Text("Diperbarui \(updated.shortText)")
                        .font(.caption).foregroundStyle(.secondary)
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

    private func part(_ title: LocalizedStringKey, _ amount: Int64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            AmountText(amount: amount, hidden: hidden).font(.subheadline.weight(.medium))
        }
    }
}
