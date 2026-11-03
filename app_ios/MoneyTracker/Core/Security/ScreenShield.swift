import SwiftUI
import UIKit

/// A window above the whole app that shows the lock screen, or the privacy cover for the app
/// switcher snapshot. Being a separate window it covers everything: tabs, pushed screens,
/// sheets, and dialogs (the lock is an overlay, not a route). Its content is `ShieldContent`,
/// which reads the container, so this class only decides whether the window is visible.
@MainActor
final class ScreenShield {
    private var window: UIWindow?

    func setVisible(_ visible: Bool, container: AppContainer) {
        if visible {
            show(container: container)
        } else {
            window?.isHidden = true
        }
    }

    private func show(container: AppContainer) {
        if window == nil {
            guard
                let scene = UIApplication.shared.connectedScenes.compactMap({
                    $0 as? UIWindowScene
                }).first
            else { return }
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(
                rootView: ShieldContent().environment(container)
                    .environment(\.locale, Locale(identifier: "id_ID")))
            host.view.backgroundColor = .clear
            host.view.accessibilityViewIsModal = true
            window.rootViewController = host
            self.window = window
        }
        // Close the keyboard of whatever field was being edited.
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        window?.isHidden = false
    }
}

/// What the shield window shows: the lock screen while locked, otherwise the privacy cover.
struct ShieldContent: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Group {
            if container.lock.locked {
                LockView(container: container)
            } else {
                PrivacyCoverView()
            }
        }
        .preferredColorScheme(container.preferences.colorScheme)
    }
}

/// Covers the app in the app switcher when a PIN or "sembunyikan nominal" is on.
struct PrivacyCoverView: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56)).foregroundStyle(AppColors.seed)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
