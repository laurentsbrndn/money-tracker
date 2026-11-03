import SwiftUI

/// One account waiting for its real balance.
struct ReconcileInputRow: View {
    let item: ReconcileItem
    let hidden: Bool
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ProviderLogoView(providerKey: item.account.providerKey)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.account.name).font(.body)
                    Text(
                        "Tercatat: \(MoneyFormatter.rupiah(item.result.expectedBalance, hidden: hidden))"
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
            MoneyField(title: "Saldo asli", text: $text, allowNegative: true)
        }
        .padding(.vertical, 4)
    }
}
