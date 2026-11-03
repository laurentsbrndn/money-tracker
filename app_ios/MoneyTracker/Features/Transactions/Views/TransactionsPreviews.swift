#if DEBUG
    import SwiftUI

    private func list(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .transactions) {
                TransactionsView(container: container)
            }
        }
    }

    #Preview("Transaksi — kosong") { list(.empty) }
    #Preview("Transaksi — berisi") { list(.populated) }
    #Preview("Transaksi — nominal disembunyikan") { list(.hiddenAmounts) }
    #Preview("Transaksi — perlu perhatian") { list(.attention) }
    #Preview("Transaksi — mode gelap") { list(.dark) }

    private func form(_ variant: PreviewVariant, _ mode: TransactionFormRequest.Mode)
        -> some View
    {
        PreviewHost(variant: variant) { container in
            TransactionFormView(container: container, request: TransactionFormRequest(mode: mode))
        }
    }

    #Preview("Form — pengeluaran baru") {
        form(.populated, .new(type: "expense", fromAccountId: nil, amount: nil))
    }
    #Preview("Form — pemasukan baru") {
        form(.populated, .new(type: "income", fromAccountId: "acc-bca", amount: 250_000))
    }
    #Preview("Form — transfer baru") {
        form(.populated, .new(type: "transfer", fromAccountId: "acc-bca", amount: nil))
    }
    #Preview("Form — ubah transaksi") { form(.populated, .edit(id: "t6")) }
    #Preview("Form — tanpa data") {
        form(.empty, .new(type: "expense", fromAccountId: nil, amount: nil))
    }
    #Preview("Form — mode gelap") {
        form(.dark, .new(type: "expense", fromAccountId: nil, amount: nil))
    }

    #Preview("Filter") {
        PreviewHost(variant: .populated) { container in
            TransactionFilterSheet(
                container: container, initial: TransactionFilter(), onApply: { _ in })
        }
    }
#endif
