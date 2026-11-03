import SwiftUI

/// One row of a transaction list: category icon, title, note, amount, and a small cloud when the
/// change has not reached the server yet.
struct TransactionRow: View {
    @Environment(AppContainer.self) private var container
    let transaction: TransactionRecord
    /// Account whose list this is; a transfer then reads as money in or out of it.
    var viewpointAccountId: String?

    var body: some View {
        let category = transaction.categoryId.flatMap { container.lookups.categories[$0] }
        let appearance = self.appearance(category)
        HStack(spacing: 12) {
            Image(systemName: appearance.symbol)
                .foregroundStyle(appearance.color)
                .frame(width: 38, height: 38)
                .background(appearance.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(appearance.title).lineLimit(1)
                if !detail.isEmpty {
                    Text(detail).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            switch transaction.syncStatus {
            case "pending":
                Image(systemName: "icloud.and.arrow.up").font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("Belum tersinkron")
            case "failed":
                Image(systemName: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
                    .accessibilityLabel("Gagal tersinkron")
            default:
                EmptyView()
            }
            AmountText(
                amount: transaction.amount, kind: appearance.kind,
                hidden: container.preferences.hideAmounts, signed: true
            )
            .fontWeight(.semibold)
        }
        .contentShape(Rectangle())
    }

    private var detail: String {
        let accounts = container.lookups.accounts
        let account = accounts[transaction.accountId]?.name ?? ""
        if transaction.type == "transfer" {
            let target = transaction.toAccountId.flatMap { accounts[$0]?.name } ?? ""
            return "\(account) → \(target)"
        }
        let text = transaction.note ?? transaction.source ?? ""
        return [text, account].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func appearance(_ category: CategoryRecord?) -> (
        symbol: String, color: Color, title: String, kind: AmountKind
    ) {
        switch transaction.type {
        case "income":
            return (
                category.map { CategoryIcons.symbol($0.icon) } ?? "arrow.down.left",
                category.map { CategoryIcons.color($0.color) } ?? AppColors.income,
                category?.name ?? String(localized: "Tanpa kategori"), .income
            )
        case "expense":
            return (
                category.map { CategoryIcons.symbol($0.icon) } ?? "arrow.up.right",
                category.map { CategoryIcons.color($0.color) } ?? AppColors.expense,
                category?.name ?? String(localized: "Tanpa kategori"), .expense
            )
        case "transfer":
            return ("arrow.left.arrow.right", .secondary, String(localized: "Transfer"), .transfer)
        default:
            return (
                "slider.horizontal.3", .secondary, String(localized: "Penyesuaian"), .neutral
            )
        }
    }
}
