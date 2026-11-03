#if DEBUG
    import SwiftUI

    /// The dashboard cards of the reconciliation, over the sample data.
    struct ReconcileCardsPreview: View {
        let container: AppContainer
        @State private var overview = ReconcileOverview()

        var body: some View {
            ScrollView {
                VStack(spacing: 12) {
                    ActualMoneyCard(overview: overview, hidden: container.preferences.hideAmounts)
                    DifferenceCard(
                        overview: overview, hidden: container.preferences.hideAmounts,
                        onReconcile: {})
                }
                .padding()
            }
            .task {
                let database = container.database
                overview =
                    (try? await database.pool.read { db in
                        ReconcileOverview.compute(
                            accounts: try db.liveAccounts(), transactions: try db.allTransactions(),
                            snapshots: try db.allSnapshots(), asOf: UserClock.today())
                    }) ?? ReconcileOverview()
            }
        }
    }

    private func reconcile(_ variant: PreviewVariant) -> some View {
        PreviewHost(variant: variant) { container in
            PreviewStack(container: container, tab: .dashboard) {
                ReconcileView(container: container)
            }
        }
    }

    #Preview("Cocokkan saldo — kosong") { reconcile(.empty) }
    #Preview("Cocokkan saldo — berisi") { reconcile(.populated) }
    #Preview("Cocokkan saldo — nominal disembunyikan") { reconcile(.hiddenAmounts) }
    #Preview("Cocokkan saldo — mode gelap") { reconcile(.dark) }

    #Preview("Kartu uang aktual & selisih") {
        PreviewHost(variant: .populated) { ReconcileCardsPreview(container: $0) }
    }
#endif
