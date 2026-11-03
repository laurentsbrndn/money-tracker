import SwiftUI

/// Cocokkan saldo (APP_FLOWS Flow 5).
struct ReconcileView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: ReconcileViewModel
    @State private var adjustTarget: ReconcileItem?

    init(container: AppContainer) {
        _model = State(initialValue: ReconcileViewModel(container: container))
    }

    private var hidden: Bool { container.preferences.hideAmounts }

    var body: some View {
        Group {
            if model.loaded && model.overview.active.isEmpty {
                EmptyStateView(
                    title: "Belum ada akun",
                    message: "Tambahkan akun lebih dulu untuk mencocokkan saldo.",
                    systemImage: "creditcard")
            } else {
                list
            }
        }
        .navigationTitle("Cocokkan saldo")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !model.overview.active.isEmpty {
                Button {
                    Task { await model.submit() }
                } label: {
                    Text("Cocokkan").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(model.busy)
                .padding()
                .background(.bar)
            }
        }
        .task { await model.start() }
        .alert(
            "Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert(
            "Buat penyesuaian?",
            isPresented: Binding(
                get: { adjustTarget != nil }, set: { if !$0 { adjustTarget = nil } }),
            presenting: adjustTarget
        ) { item in
            Button("Batal", role: .cancel) {}
            Button("Buat penyesuaian") { Task { await model.adjust(item.id) } }
        } message: { item in
            let amount = MoneyFormatter.signedRupiah(item.result.diff, hidden: hidden)
            Text(
                "Satu transaksi penyesuaian sebesar \(amount) dibuat supaya saldo tercatat sama dengan saldo asli. Penyesuaian tidak dihitung sebagai pemasukan atau pengeluaran."
            )
        }
    }

    private var list: some View {
        List {
            Section {
                Text(
                    "Isi saldo asli tiap akun sesuai aplikasi bank, e-wallet, atau uang di tanganmu. Akun yang dikosongkan dilewati."
                )
                .font(.subheadline).foregroundStyle(.secondary)
            }
            if !model.reconciledItems.isEmpty {
                Section {
                    ReconcileSummaryCard(
                        matched: model.matchedCount, total: model.reconciledItems.count,
                        adjustedTotal: model.adjustedTotal, hidden: hidden)
                }
            }
            Section {
                ForEach(model.overview.active) { item in
                    if model.reconciled.contains(item.id) {
                        ReconcileResultRow(
                            item: item, hidden: hidden, deferred: model.deferred.contains(item.id),
                            adjustedAmount: model.adjusted[item.id], busy: model.busy,
                            onMissed: { recordMissed(item) }, onAdjust: { adjustTarget = item },
                            onLater: { model.postpone(item.id) },
                            onReview: { model.undefer(item.id) })
                    } else {
                        ReconcileInputRow(
                            item: item, hidden: hidden,
                            text: Binding(
                                get: { model.inputs[item.id] ?? "" },
                                set: { model.inputs[item.id] = $0 }))
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func recordMissed(_ item: ReconcileItem) {
        let diff = item.result.diff
        // A real balance lower than the recorded one means an expense is missing.
        container.router.openTransactionForm(
            type: diff < 0 ? "expense" : "income", fromAccountId: item.id, amount: abs(diff))
    }
}
