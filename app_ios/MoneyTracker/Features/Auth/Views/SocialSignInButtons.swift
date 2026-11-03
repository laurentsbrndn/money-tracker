import AuthenticationServices
import SwiftUI

/// "Lanjutkan dengan Apple" (paling atas, FRONTEND_IOS §5), "Lanjutkan dengan Google", and the
/// "atau" divider that separates them from the email form.
struct SocialSignInButtons: View {
    let social: SocialSignIn
    let disabled: Bool

    @State private var appleNonce = ""
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.continue) { request in
                appleNonce = AppleSignInCoordinator.prepare(request)
            } onCompletion: { result in
                let nonce = appleNonce
                Task { await social.apple(result, nonce: nonce) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .disabled(disabled)

            Button {
                Task { await social.google() }
            } label: {
                Label("Lanjutkan dengan Google", systemImage: "globe")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            .disabled(disabled)

            HStack {
                Rectangle().fill(.separator).frame(height: 1)
                Text("atau").font(.footnote).foregroundStyle(.secondary)
                Rectangle().fill(.separator).frame(height: 1)
            }
        }
    }
}
