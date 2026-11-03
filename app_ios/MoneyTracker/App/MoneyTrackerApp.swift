import GoogleSignIn
import SwiftUI

@main
struct MoneyTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(delegate.container)
                .onOpenURL { url in
                    // Google Sign-In returns to the app through its reversed client ID scheme.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
