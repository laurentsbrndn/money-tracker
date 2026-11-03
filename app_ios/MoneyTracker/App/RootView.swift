import SwiftUI

/// Chooses the top-level screen. Splash, onboarding, auth, lock and upgrade states join
/// here in Phase 1; for now the app always shows the main tabs.
struct RootView: View {
    var body: some View {
        MainTabView()
    }
}
