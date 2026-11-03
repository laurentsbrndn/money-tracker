import SwiftUI

/// The server refused this app version (`426 upgrade_required`, API.md §1.1): nothing else is
/// usable until the app is updated.
struct UpgradeRequiredView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 64))
                .foregroundStyle(AppColors.seed)
            Text("Perbarui aplikasi").font(.title.bold())
            Text(
                "Versi aplikasi ini sudah terlalu lama. Perbarui lewat App Store untuk melanjutkan."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
