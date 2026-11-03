import SwiftUI

/// Header chip with the sync state (FRONTEND_IOS §4.3). Tapping it opens the screen that fits:
/// login when the session ended, sync settings otherwise.
struct SyncBadge: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        let state = container.syncStatus.badge
        let appearance = Self.appearance(for: state)
        Button {
            if state == .needsLogin {
                container.router.showReLogin = true
            } else {
                container.router.openSyncSettings()
            }
        } label: {
            Label {
                Text(appearance.label)
            } icon: {
                Image(systemName: appearance.symbol)
                    .symbolEffect(.pulse, isActive: state == .syncing)
            }
            .font(.footnote)
            .foregroundStyle(appearance.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(appearance.color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private static func appearance(for state: SyncBadgeState) -> (
        label: LocalizedStringKey, symbol: String, color: Color
    ) {
        switch state {
        case .synced: ("Tersinkron", "checkmark.icloud", AppColors.seed)
        case .syncing: ("Menyinkronkan…", "arrow.triangle.2.circlepath.icloud", AppColors.seed)
        case .pending(let count): ("Menunggu sync (\(count))", "icloud.and.arrow.up", .orange)
        case .offline: ("Offline", "icloud.slash", .secondary)
        case .needsLogin: ("Perlu login", "lock", .red)
        case .attention(let count): ("Perlu perhatian (\(count))", "exclamationmark.circle", .red)
        }
    }
}
