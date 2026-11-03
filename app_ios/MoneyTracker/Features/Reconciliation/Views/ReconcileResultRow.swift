import SwiftUI

/// The outcome for one account after its balance was entered: matched, or the difference with
/// the three choices of APP_FLOWS Flow 5 step 4.
struct ReconcileResultRow: View {
    let item: ReconcileItem
    let hidden: Bool
    let deferred: Bool
    /// Signed adjustment booked in this visit, nil if none.
    let adjustedAmount: Int64?
    let busy: Bool
    let onMissed: () -> Void
    let onAdjust: () -> Void
    let onLater: () -> Void
    let onReview: () -> Void

    private var matched: Bool { item.result.status == .matched }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProviderLogoView(providerKey: item.account.providerKey)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.account.name)
                    HStack(spacing: 4) {
                        Text("Saldo asli")
                        AmountText(amount: item.result.latestSnapshotAmount, hidden: hidden)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if matched {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.income)
                }
            }
            if matched {
                Text(matchedText).font(.subheadline).foregroundStyle(AppColors.income)
            } else {
                Text(diffText).font(.subheadline.weight(.semibold)).foregroundStyle(
                    AppColors.expense)
                if deferred {
                    Button("Tinjau lagi", action: onReview)
                } else {
                    // Three plain buttons in a list row must not turn the whole row into one tap.
                    HStack(spacing: 8) {
                        Button("Catat yang terlewat", action: onMissed)
                        Button("Buat penyesuaian", action: onAdjust)
                        Button("Nanti saja", action: onLater)
                    }
                    .buttonStyle(.bordered).controlSize(.small).disabled(busy)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var matchedText: String {
        guard let adjustedAmount else { return String(localized: "Cocok") }
        let amount = MoneyFormatter.signedRupiah(adjustedAmount, hidden: hidden)
        return String(localized: "Cocok · Disesuaikan \(amount)")
    }

    private var diffText: String {
        let amount = MoneyFormatter.signedRupiah(item.result.diff, hidden: hidden)
        let text = String(localized: "Selisih \(amount)")
        return deferred ? String(localized: "Ditunda · \(text)") : text
    }
}
