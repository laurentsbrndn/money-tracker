import SwiftUI

/// Lainnya → Transaksi berulang (APP_FLOWS Flow 10).
struct RecurringView: View {
    @Environment(AppContainer.self) private var container
    @State private var model: RecurringViewModel

    init(container: AppContainer) {
        _model = State(initialValue: RecurringViewModel(container: container))
    }

    var body: some View {
        let premium = container.premium.isPremium
        List {
            if model.loaded && model.rules.isEmpty {
                EmptyStateView(
                    title: premium ? "Belum ada transaksi berulang" : "Transaksi berulang untuk Premium",
                    message: premium
                        ? "Buat aturan untuk gaji, tagihan, atau langganan yang datang tiap periode."
                        : "Dengan Premium, transaksi rutin dicatat otomatis atau menunggu konfirmasimu.",
                    systemImage: "repeat"
                )
                .listRowBackground(Color.clear)
            }
            if !premium && model.rules.contains(where: \.isPaused) {
                Section {
                    Text(
                        "Aturan ini dijeda otomatis karena Premium berakhir. Aturan lanjut setelah kamu berlangganan Premium lagi."
                    )
                    Button("Lihat Premium") { container.router.push(.paywall(restore: false)) }
                }
            }
            Section {
                ForEach(model.rules) { rule in
                    NavigationLink(value: AppRoute.recurringForm(id: rule.id, prefill: nil)) {
                        RecurringRuleRow(
                            rule: rule, title: title(of: rule), today: UserClock.today(),
                            premium: premium, hideAmounts: container.preferences.hideAmounts
                        ) { Task { await model.togglePause(rule) } }
                    }
                }
            }
        }
        .navigationTitle("Transaksi berulang")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    container.router.push(
                        premium
                            ? .recurringForm(id: nil, prefill: nil) : .paywall(restore: false))
                } label: {
                    Label("Tambah aturan", systemImage: "plus")
                }
            }
        }
        .task { await model.observe() }
        .alert("Melanjutkan aturan butuh Premium.", isPresented: $model.needsPremium) {
            Button("Lihat Premium") { container.router.push(.paywall(restore: false)) }
            Button("Tutup", role: .cancel) {}
        }
        .alert("Terjadi kesalahan", isPresented: .constant(model.errorMessage != nil)) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func title(of rule: RecurringRuleRecord) -> String {
        if rule.type == "transfer" { return String(localized: "Transfer") }
        return rule.categoryId.flatMap { container.lookups.categories[$0]?.name }
            ?? String(localized: "Tanpa kategori")
    }
}
