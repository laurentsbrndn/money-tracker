#if DEBUG
    import SwiftUI

    private func accounts(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .accounts) {
                AccountsView(container: container)
            }
        }
    }

    #Preview("Akun — kosong") { accounts(.empty) }
    #Preview("Akun — berisi") { accounts(.populated) }
    #Preview("Akun — nominal disembunyikan") { accounts(.hiddenAmounts) }
    #Preview("Akun — mode gelap") { accounts(.dark) }

    private func detail(_ variant: PreviewVariant, _ id: String) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .accounts) {
                AccountDetailView(container: container, accountId: id)
            }
        }
    }

    #Preview("Detail akun — selisih (Cash)") { detail(.populated, "acc-cash") }
    #Preview("Detail akun — cocok (BCA)") { detail(.populated, "acc-bca") }
    #Preview("Detail akun — usang (Jago)") { detail(.populated, "acc-jago") }
    #Preview("Detail akun — mode gelap") { detail(.dark, "acc-bca") }

    #Preview("Form akun — baru") {
        PreviewHost(variant: .populated) { container in
            NavigationStack { AccountFormView(container: container, accountId: nil) }
        }
    }

    #Preview("Form akun — ubah") {
        PreviewHost(variant: .populated) { container in
            NavigationStack { AccountFormView(container: container, accountId: "acc-bca") }
        }
    }
#endif
