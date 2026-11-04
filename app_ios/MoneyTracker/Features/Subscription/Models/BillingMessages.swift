import Foundation

/// The Indonesian explanation of a store failure.
func billingFailureMessage(_ failure: BillingFailure) -> String {
    switch failure {
    case .unavailable: String(localized: "Pembelian belum diaktifkan di versi aplikasi ini.")
    case .network:
        String(localized: "Tidak bisa terhubung ke App Store. Periksa koneksi lalu coba lagi.")
    case .noProducts: String(localized: "Paket langganan belum tersedia saat ini. Coba lagi nanti.")
    case .productUnavailable: String(localized: "Paket ini tidak bisa dibeli saat ini.")
    case .notAllowed:
        String(localized: "Pembelian tidak diizinkan di akun App Store ini, atau App Store sedang bermasalah.")
    case .busy: String(localized: "Masih ada proses pembelian yang berjalan.")
    case .accountLink: String(localized: "Akunmu belum bisa dihubungkan ke toko. Coba lagi.")
    case .unknown: String(localized: "Terjadi kesalahan pada pembelian. Coba lagi.")
    }
}

/// The one-line result of the last purchase or restore, or nil.
func subscriptionNoticeMessage(_ notice: SubscriptionNotice) -> String? {
    switch notice {
    case .none: nil
    case .cancelled: String(localized: "Pembelian dibatalkan.")
    case .pending:
        String(localized: "Pembayaran menunggu persetujuan. Premium aktif setelah pembayaran selesai.")
    case .restoreNothing:
        String(localized: "Tidak ada pembelian aktif yang bisa dipulihkan untuk akun ini.")
    case .sessionExpired: String(localized: "Sesi berakhir. Masuk lagi untuk melanjutkan.")
    case .failure(let failure): billingFailureMessage(failure)
    }
}
