#if DEBUG
    import SwiftUI

    private func list(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) { RecurringView(container: container) }
        }
    }

    private func form(_ variant: PreviewVariant, ruleId: String?) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .more) {
                RecurringFormView(container: container, ruleId: ruleId, prefill: nil)
            }
        }
    }

    #Preview("Transaksi berulang — kosong") { list(.empty) }
    #Preview("Transaksi berulang — Premium") { list(.premium) }
    #Preview("Transaksi berulang — dijeda server (gratis)") { list(.populated) }
    #Preview("Transaksi berulang — nominal disembunyikan") { list(.hiddenAmounts) }
    #Preview("Aturan baru — Premium") { form(.premium, ruleId: nil) }
    #Preview("Aturan baru — gratis (terkunci)") { form(.populated, ruleId: nil) }
    #Preview("Ubah aturan") { form(.premium, ruleId: "rule-gym") }

    #Preview("Menunggu konfirmasi") {
        PreviewHost(variant: .premium) { container in
            PreviewStack(container: container, tab: .transactions) {
                TransactionsView(container: container)
            }
        }
    }
#endif
