import SwiftUI

/// Shown while the session and the local flags are being read.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "banknote")
                .font(.system(size: 56))
                .foregroundStyle(AppColors.seed)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
