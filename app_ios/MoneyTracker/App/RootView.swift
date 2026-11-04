import SwiftUI

/// Chooses the top-level screen from the app gate (APP_FLOWS Flow 1): splash, onboarding and
/// auth, initial sync, setup wizard, or the main tabs; the update screen overrides all of them.
/// The app lock is not a screen here: `ScreenShield` draws it in a window above everything.
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
        .environment(\.calendar, container.preferences.calendar)
        .preferredColorScheme(container.preferences.colorScheme)
        .animation(.default, value: container.gate.gate)
        .sheet(isPresented: $router.showReLogin) { ReLoginView() }
        // Until the lock window is up (the very first frame), nothing of the app may show.
        .overlay { if container.lock.locked { Color(.systemBackground).ignoresSafeArea() } }
        .onChange(of: container.session.status) { _, status in
            if status != .needsLogin { router.showReLogin = false }
            if status == .signedOut {
                router.reset()
                container.lock.clearAll()
                Task { await container.notifications.cancelAll() }
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            container.scheduler.scenePhaseChanged(phase)
            container.lock.scenePhaseChanged(phase)
            if phase == .active {
                Task {
                    // The 3-day offline tolerance can run out without a database change.
                    await container.premium.refresh()
                    container.recurringCoordinator.requestRun()
                }
            }
            if phase == .active { container.notifications.requestRefresh() }
            // Retries when the window could not be made yet at launch.
            container.shield.setVisible(shieldVisible, container: container)
        }
        .onChange(of: shieldVisible, initial: true) { _, visible in
            container.shield.setVisible(visible, container: container)
        }
        .onChange(of: router.pendingRoute, initial: true) { openPendingRoute() }
        .onChange(of: container.gate.gate) { openPendingRoute() }
    }

    /// The lock screen while locked; the privacy cover while the app is not active (app
    /// switcher snapshot) and a PIN or "sembunyikan nominal" is on.
    private var shieldVisible: Bool {
        container.lock.locked
            || (scenePhase != .active
                && (container.lock.pinSet || container.preferences.hideAmounts))
    }

    private func openPendingRoute() {
        guard container.gate.gate == .ready, let route = container.router.pendingRoute else {
            return
        }
        container.router.pendingRoute = nil
        container.router.open(route)
    }
}
