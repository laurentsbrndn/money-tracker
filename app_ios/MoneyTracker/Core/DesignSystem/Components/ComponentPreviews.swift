#if DEBUG
    import SwiftUI

    #Preview("SyncBadge — semua state") {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(PreviewVariant.allCases.filter { $0 != .empty && $0 != .hiddenAmounts }) {
                variant in
                PreviewHost(variant: variant) { _ in SyncBadge() }
                    .frame(height: 32)
            }
        }
        .padding()
    }

    #Preview("EmptyStateView") {
        EmptyStateView(
            title: "Belum ada transaksi", message: "Transaksi yang kamu catat muncul di sini.",
            systemImage: "list.bullet", actionTitle: "Catat transaksi", action: {})
    }

    #Preview("EmptyStateView — tanpa aksi, gelap") {
        EmptyStateView(
            title: "Tidak ada hasil", message: "Coba ubah atau hapus filter pencarian.",
            systemImage: "magnifyingglass"
        )
        .preferredColorScheme(.dark)
    }

    #Preview("AmountText") {
        VStack(alignment: .leading, spacing: 8) {
            AmountText(amount: 8_000_000, kind: .income)
            AmountText(amount: 1_852_500, kind: .expense)
            AmountText(amount: 6_147_500)
            AmountText(amount: -50_000, signed: true)
            AmountText(amount: 6_147_500, hidden: true)
        }
        .padding()
    }

    private struct FieldsDemo: View {
        @State private var amount = "1.500.000"
        @State private var password = "rahasia123"

        var body: some View {
            Form {
                MoneyField(title: "Nominal", text: $amount)
                PasswordField(title: "Kata sandi", text: $password)
            }
        }
    }

    #Preview("MoneyField & PasswordField") { FieldsDemo() }

    #Preview("NumpadView") {
        NumpadView(onDigits: { _ in }, onBackspace: {}, onClear: {}).padding()
    }

    #Preview("ProviderLogoView") {
        HStack(spacing: 12) {
            ForEach(["bca", "mandiri", "gopay", "jago", nil], id: \.self) { key in
                ProviderLogoView(providerKey: key)
            }
        }
        .padding()
    }

    #Preview("AddTransactionButton") {
        PreviewHost(variant: .populated) { _ in AddTransactionButton() }
    }
#endif
