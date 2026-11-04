import SwiftUI

/// One selectable package of the paywall.
struct PackageTile: View {
    let package: PaywallPackage
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(price).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if package.hasTrial {
                    Text("Uji coba gratis")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.35),
                        lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var title: String {
        switch package.period {
        case .monthly: String(localized: "Bulanan")
        case .yearly: String(localized: "Tahunan")
        case .other: package.title
        }
    }

    private var price: String {
        switch package.period {
        case .monthly: String(localized: "\(package.priceText) / bulan")
        case .yearly: String(localized: "\(package.priceText) / tahun")
        case .other: package.priceText
        }
    }
}
