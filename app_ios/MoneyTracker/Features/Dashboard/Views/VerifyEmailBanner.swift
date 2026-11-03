import SwiftUI

/// Shown until the email is verified; the app stays usable meanwhile (APP_FLOWS Flow 1).
struct VerifyEmailBanner: View {
    let onVerify: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "envelope.badge").foregroundStyle(.orange)
            Text("Verifikasi emailmu").font(.subheadline)
            Spacer()
            Button("Verifikasi", action: onVerify).buttonStyle(.bordered).controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}
