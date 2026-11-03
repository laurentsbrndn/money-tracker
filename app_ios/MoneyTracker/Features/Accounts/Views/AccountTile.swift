import SwiftUI

/// One account in the list: the latest real balance with its date, the recorded (expected)
/// balance, and a badge when the two differ or the real balance is old (APP_FLOWS Flow 5).
struct AccountTile: View {
    @Environment(AppContainer.self) private var container
    let item: AccountWithBalance

    private var hidden: Bool { container.preferences.hideAmounts }

    var body: some View {
        HStack(spacing: 12) {
            ProviderLogoView(providerKey: item.account.providerKey)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.account.name).font(.body)
                if !item.account.includeInTotal {
                    Text("Tidak dihitung di total").font(.caption).foregroundStyle(.secondary)
                } else if let result = item.reconciliation, result.hasSnapshot,
                    let date = result.latestSnapshotDate
                {
                    Text("Saldo asli \(date.shortText)").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(AccountTypeLabels.label(item.account.type))
                        .font(.caption).foregroundStyle(.secondary)
                }
                badge
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let result = item.reconciliation, result.hasSnapshot {
                    AmountText(amount: result.latestSnapshotAmount, hidden: hidden)
                    HStack(spacing: 4) {
                        Text("Tercatat")
                        AmountText(amount: item.expectedBalance, hidden: hidden)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                } else {
                    AmountText(amount: item.expectedBalance, hidden: hidden)
                }
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        if let result = item.reconciliation, item.account.archivedAt == nil {
            switch result.status {
            case .mismatch:
                Label(
                    "Selisih \(MoneyFormatter.signedRupiah(result.diff, hidden: hidden))",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption2.weight(.semibold)).foregroundStyle(AppColors.warning)
            case .stale:
                Label("Perlu diperbarui", systemImage: "clock.arrow.circlepath")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            case .matched:
                Label("Cocok", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold)).foregroundStyle(AppColors.income)
            }
        }
    }
}
