import SwiftUI

struct AccountTile: View {
    @Environment(AppContainer.self) private var container
    let item: AccountWithBalance

    var body: some View {
        HStack(spacing: 12) {
            ProviderLogoView(providerKey: item.account.providerKey)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.account.name).font(.body)
                if !item.account.includeInTotal {
                    Text("Tidak dihitung di total").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(AccountTypeLabels.label(item.account.type))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            AmountText(amount: item.expectedBalance, hidden: container.preferences.hideAmounts)
        }
    }
}
