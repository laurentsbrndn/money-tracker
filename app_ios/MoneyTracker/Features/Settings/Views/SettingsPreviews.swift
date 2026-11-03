#if DEBUG
    import SwiftUI

    private func more(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { MoreView(container: container) }
        }
    }

    #Preview("Lainnya — berisi") { more(.populated) }
    #Preview("Lainnya — perlu perhatian") { more(.attention) }
    #Preview("Lainnya — mode gelap") { more(.dark) }

    private func syncSettings(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) {
                SyncSettingsView(container: container)
            }
        }
    }

    #Preview("Sinkronisasi — tersinkron") { syncSettings(.populated) }
    #Preview("Sinkronisasi — menunggu") { syncSettings(.pending) }
    #Preview("Sinkronisasi — offline") { syncSettings(.offline) }
    #Preview("Sinkronisasi — perlu perhatian") { syncSettings(.attention) }
    #Preview("Sinkronisasi — mode gelap") { syncSettings(.dark) }

    #Preview("Profil") {
        PreviewHost(variant: .populated) { container in
            PreviewStack(container: container, tab: .more) { ProfileView(container: container) }
        }
    }

    #Preview("Ganti kata sandi") {
        PreviewHost(variant: .populated) { container in
            PreviewStack(container: container, tab: .more) {
                ChangePasswordView(container: container)
            }
        }
    }

    #Preview("Hapus akun") {
        PreviewHost(variant: .populated) { container in
            PreviewStack(container: container, tab: .more) {
                DeleteAccountView(container: container)
            }
        }
    }

    #Preview("Perbarui aplikasi (upgrade required)") { UpgradeRequiredView() }

    #Preview("Perbarui aplikasi — mode gelap") {
        UpgradeRequiredView().preferredColorScheme(.dark)
    }
#endif

#if DEBUG
    private func moreScreen(_ variant: PreviewVariant, _ screen: MoreScreen) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) {
                switch screen {
                case .preferences: AnyView(PreferencesView(container: container))
                case .security: AnyView(SecurityView(container: container))
                case .pin: AnyView(PinSetupView(container: container, mode: .set))
                case .notifications: AnyView(NotificationSettingsView(container: container))
                }
            }
        }
    }

    private enum MoreScreen { case preferences, security, pin, notifications }

    #Preview("Preferensi") { moreScreen(.populated, .preferences) }
    #Preview("Preferensi — mode gelap") { moreScreen(.dark, .preferences) }
    #Preview("Keamanan") { moreScreen(.populated, .security) }
    #Preview("Keamanan — nominal disembunyikan") { moreScreen(.hiddenAmounts, .security) }
    #Preview("Atur PIN") { moreScreen(.populated, .pin) }
    #Preview("Notifikasi") { moreScreen(.populated, .notifications) }
    #Preview("Notifikasi — mode gelap") { moreScreen(.dark, .notifications) }
    #Preview("Layar kunci") { PreviewHost(variant: .populated) { LockView(container: $0) } }
    #Preview("Layar kunci — mode gelap") { PreviewHost(variant: .dark) { LockView(container: $0) } }
    #Preview("Pilih timezone") {
        NavigationStack { TimezonePickerView(selected: "Asia/Jakarta", onSelect: { _ in }) }
    }
#endif
