import SwiftUI

/// The paywall (APP_FLOWS Flow 9), built from the store's offering: benefits, packages, buy,
/// restore, terms and privacy. After a purchase it waits for the server to confirm premium; the
/// store SDK is never the source of premium.
struct PaywallView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var selectedID: String?

    /// Starts a restore of past purchases as soon as the screen opens.
    var restoreOnOpen = false

    private var model: SubscriptionViewModel { container.subscription }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
                links
            }
            .padding(16)
        }
        .navigationTitle("Money Tracker Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await model.open()
            selectedID = defaultSelection
            if restoreOnOpen, await container.billing.isAvailable { await model.restore() }
        }
        .onChange(of: model.packages) { _, _ in
            if selectedID == nil || !model.packages.contains(where: { $0.id == selectedID }) {
                selectedID = defaultSelection
            }
        }
    }

    /// The yearly package is the default pick when it is offered.
    private var defaultSelection: String? {
        (model.packages.first { $0.period == .yearly } ?? model.packages.first)?.id
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .processing:
            status(
                icon: "hourglass", title: "Memproses pembelian…",
                body: "Menunggu server mengaktifkan Premium. Biasanya hanya beberapa detik.",
                showsProgress: true)
        case .confirmed:
            status(
                icon: "checkmark.seal.fill", title: "Premium aktif",
                body: "Terima kasih! Semua fitur Premium sudah terbuka.")
            Button("Selesai") { dismiss() }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
        case .timedOut:
            status(
                icon: "exclamationmark.triangle", title: "Pembayaran diterima, aktivasi belum selesai",
                body:
                    "Server belum mengonfirmasi Premium. Ini bisa terjadi bila koneksi lambat. Periksa lagi sebentar lagi; kamu tidak perlu membayar ulang."
            )
            Button("Periksa lagi") { Task { await model.checkAgain() } }
                .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
        case .idle, .purchasing:
            offer
        }
    }

    @ViewBuilder
    private var offer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Money Tracker Premium").font(.title2.bold())
            Text("Catat tanpa batas dan lihat gambaran keuanganmu lebih jelas.")
                .foregroundStyle(.secondary)
        }
        VStack(alignment: .leading, spacing: 8) {
            benefit("Akun dan kategori buatan sendiri tanpa batas")
            benefit("Riwayat semua bulan")
            benefit("Laporan tren, perbandingan, dan selisih tidak tercatat")
            benefit("Transaksi berulang, otomatis atau dengan konfirmasi")
            benefit("Export CSV dan PDF")
        }
        if let message = subscriptionNoticeMessage(model.notice) {
            Text(message).font(.callout).foregroundStyle(.orange)
        }
        if let failure = model.packagesFailure {
            VStack(alignment: .leading, spacing: 8) {
                Text(failure == .unavailable ? "Langganan belum tersedia" : "Paket belum bisa dimuat")
                    .font(.headline)
                Text(billingFailureMessage(failure)).foregroundStyle(.secondary)
                if failure != .unavailable {
                    Button("Coba lagi") { Task { await model.loadPackages() } }
                }
            }
        } else if model.packagesLoading && model.packages.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            ForEach(model.packages) { package in
                PackageTile(package: package, selected: selectedID == package.id) {
                    selectedID = package.id
                }
            }
            Button {
                if let selectedID { Task { await model.buy(selectedID) } }
            } label: {
                if model.phase == .purchasing {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Berlangganan").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(selectedID == nil || model.busy)
        }
        Button("Pulihkan pembelian") { Task { await model.restore() } }
            .frame(maxWidth: .infinity)
            .disabled(model.busy || model.packagesFailure == .unavailable)
        Text(
            "Langganan diperpanjang otomatis dan bisa dibatalkan kapan saja di pengaturan Apple ID. Uji coba gratis hanya untuk pengguna yang memenuhi syarat."
        )
        .font(.footnote).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var links: some View {
        HStack(spacing: 16) {
            if let url = container.config.termsURL {
                Button("Syarat & Ketentuan") { openURL(url) }
            }
            if let url = container.config.privacyURL {
                Button("Kebijakan Privasi") { openURL(url) }
            }
        }
        .font(.footnote).frame(maxWidth: .infinity)
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .symbolRenderingMode(.multicolor)
    }

    private func status(
        icon: String, title: LocalizedStringKey, body: LocalizedStringKey,
        showsProgress: Bool = false
    ) -> some View {
        VStack(spacing: 12) {
            if showsProgress { ProgressView() }
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Color.accentColor)
            Text(title).font(.title3.bold()).multilineTextAlignment(.center)
            Text(body).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}
