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
