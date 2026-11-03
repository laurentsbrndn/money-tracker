import SwiftUI

/// A provider logo from the asset catalog (`logo_<key>`); while that image is absent it shows
/// the provider's initials, so the screens work before the logos are added.
struct ProviderLogoView: View {
    let providerKey: String?
    var size: CGFloat = 40

    var body: some View {
        if let providerKey, UIImage(named: ProviderLogos.assetName(providerKey)) != nil {
            Image(ProviderLogos.assetName(providerKey))
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            let name = ProviderLogos.name(of: providerKey) ?? "?"
            Text(name.prefix(2).uppercased())
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(.quaternary, in: Circle())
        }
    }
}
