#if DEBUG
    import SwiftUI

    private func home(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .dashboard) { HomeView(container: container) }
        }
    }

    #Preview("Beranda — kosong") { home(.empty) }
    #Preview("Beranda — berisi") { home(.populated) }
    #Preview("Beranda — nominal disembunyikan") { home(.hiddenAmounts) }
    #Preview("Beranda — offline") { home(.offline) }
    #Preview("Beranda — perlu login") { home(.needsLogin) }
    #Preview("Beranda — perlu perhatian") { home(.attention) }
    #Preview("Beranda — mode gelap") { home(.dark) }

    #Preview("Beranda — email belum diverifikasi") {
        PreviewHost(variant: .populated) { container in
            let _ = container.session.applyPreview(
                status: .authenticated, user: .preview(emailVerified: false))
            PreviewStack(container: container, tab: .dashboard) { HomeView(container: container) }
        }
    }

    #Preview("Aplikasi lengkap (tab)") {
        PreviewHost(variant: .populated) { _ in MainTabView() }
    }
#endif
