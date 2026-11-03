import UIKit

/// Owns the `AppContainer` so the background sync task can be registered before the app finishes
/// launching, including when iOS launches the app only to run it (FRONTEND_IOS §4.3).
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    let container = AppContainer()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        container.background.register()
        return true
    }
}
