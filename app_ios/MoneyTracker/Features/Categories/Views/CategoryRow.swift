import SwiftUI

struct CategoryRow: View {
    let category: CategoryRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: CategoryIcons.symbol(category.icon))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(CategoryIcons.color(category.color), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                HStack(spacing: 6) {
                    if category.isDefault { badge("Bawaan") }
                    if category.isHidden { badge("Disembunyikan") }
                    if category.archivedAt != nil { badge("Diarsipkan") }
                    if let allocation = category.defaultAllocation {
                        badge(LocalizedStringKey(allocation.capitalized))
                    }
                }
            }
        }
        .opacity(category.archivedAt != nil || category.isHidden ? 0.6 : 1)
    }

    private func badge(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption2).foregroundStyle(.secondary)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }
}
