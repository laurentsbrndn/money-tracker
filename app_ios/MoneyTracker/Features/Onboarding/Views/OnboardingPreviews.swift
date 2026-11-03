#if DEBUG
    import SwiftUI

    #Preview("Onboarding") {
        PreviewHost(variant: .empty, signedOut: true) { _ in
            OnboardingView(onStart: {}, onLogin: {})
        }
    }

    #Preview("Onboarding — mode gelap") {
        PreviewHost(variant: .dark, signedOut: true) { _ in
            OnboardingView(onStart: {}, onLogin: {})
        }
    }

    #Preview("Alur auth lengkap") {
        PreviewHost(variant: .empty, signedOut: true) { _ in AuthFlowView() }
    }

    #Preview("Splash") {
        PreviewHost(variant: .empty) { _ in SplashView() }
    }

    #Preview("Wizard — akun kosong") {
        PreviewHost(variant: .empty) { container in SetupWizardView(container: container) }
    }

    #Preview("Wizard — berisi") {
        PreviewHost(variant: .populated) { container in SetupWizardView(container: container) }
    }

    #Preview("Wizard — mode gelap") {
        PreviewHost(variant: .dark) { container in SetupWizardView(container: container) }
    }

    #Preview("Sinkronisasi awal") {
        PreviewHost(variant: .syncing) { container in InitialSyncView(container: container) }
    }

    #Preview("Sinkronisasi awal — offline") {
        PreviewHost(variant: .offline) { container in InitialSyncView(container: container) }
    }

    #Preview("Login ulang") {
        PreviewHost(variant: .needsLogin) { _ in ReLoginView() }
    }
#endif
