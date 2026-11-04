import StoreKit
import SwiftUI

/// Lainnya → Langganan: the plan, when it renews or ends, and the way to manage it. All of it is
/// the server's entitlement as cached by the last sync.
struct SubscriptionView: View {
    @Environment(AppContainer.self) private var container
    @State private var managementFailed = false

    var body: some View {
        let info = container.premium.info
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        info.premium ? "Premium aktif" : "Paket gratis",
                        systemImage: info.premium ? "star.circle.fill" : "person.circle"
                    ).font(.title3.bold())
                    if info.premium {
                        Text("Paket: \(planName(info.productID))")
                        if let expires = info.expiresAt {
                            let date = Self.longDate(expires)
                            Text(
                                info.willRenew
                                    ? "Diperpanjang otomatis pada \(date)"
                                    : "Berakhir pada \(date), tidak diperpanjang")
                        }
                        if info.isInTolerance(now: Date()) {
                            Text(
                                "Langganan sudah berakhir menurut data terakhir dari server. Fitur Premium tetap terbuka sementara bila tidak ada koneksi."
                            ).font(.footnote).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(
                            "Tingkatkan ke Premium untuk akun dan kategori tanpa batas, riwayat semua bulan, laporan tren, transaksi berulang, dan export."
                        ).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                if !info.premium {
                    NavigationLink(value: AppRoute.paywall(restore: false)) {
                        Text("Lihat paket Premium")
                    }
                } else if info.store == nil || info.store == "app_store" {
                    Button("Kelola langganan") { Task { await manage() } }
                }
                NavigationLink(value: AppRoute.paywall(restore: true)) {
                    Text("Pulihkan pembelian")
                }
            }
        }
        .navigationTitle("Langganan")
        .task { await container.subscription.refreshStatus() }
        .alert("Tidak bisa membuka pengaturan langganan.", isPresented: $managementFailed) {
            Button("Tutup", role: .cancel) {}
        }
    }

    private func manage() async {
        guard
            let scene = UIApplication.shared.connectedScenes.first(where: {
                $0.activationState == .foregroundActive
            }) as? UIWindowScene
        else {
            managementFailed = true
            return
        }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            managementFailed = true
        }
    }

    private func planName(_ productID: String?) -> String {
        guard let productID else { return String(localized: "Premium") }
        if productID.contains("year") { return String(localized: "Premium tahunan") }
        if productID.contains("month") { return String(localized: "Premium bulanan") }
        return String(localized: "Premium")
    }

    /// The date in the user's timezone (`UserClock`), not the device's.
    private static func longDate(_ instant: Date) -> String {
        CivilDate(instant, in: UserClock.timeZone).longText
    }
}
