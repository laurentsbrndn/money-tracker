import SwiftUI

/// Chooses the top-level screen from the app gate (APP_FLOWS Flow 1): splash, onboarding and
/// auth, initial sync, setup wizard, or the main tabs; the update screen overrides all of them.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = container.router

        Group {
            if container.upgrade.isRequired {
                UpgradeRequiredView()
            } else {
                switch container.gate.gate {
                case .loading: SplashView()
                case .signedOut: AuthFlowView()
                case .initialSync: InitialSyncView(container: container)
                case .setup: SetupWizardView(container: container)
                case .ready: MainTabView()
                }
            }
        }
        .environment(\.locale, Locale(identifier: "id_ID"))
        .animation(.default, value: container.gate.gate)
        .sheet(isPresented: $router.showReLogin) { ReLoginView() }
        .onChange(of: container.session.status) { _, status in
            if status != .needsLogin { router.showReLogin = false }
            if status == .signedOut { router.reset() }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            container.scheduler.scenePhaseChanged(phase)
        }
    }
}
