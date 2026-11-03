import SwiftUI

/// The category grid of the entry form.
struct CategoryPicker: View {
    let categories: [CategoryRecord]
    let selectedId: String?
    let onSelect: (CategoryRecord) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
            ForEach(categories) { category in
                let selected = category.id == selectedId
                let color = CategoryIcons.color(category.color)
                VStack(spacing: 4) {
                    Image(systemName: CategoryIcons.symbol(category.icon))
                        .foregroundStyle(selected ? .white : color)
                        .frame(width: 40, height: 40)
                        .background(selected ? color : color.opacity(0.15), in: Circle())
                    Text(category.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    selected ? color.opacity(0.12) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelect(category) }
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
