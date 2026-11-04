import Foundation

/// A free-plan limit was reached (SYNC_PROTOCOL §8.3 `plan_limit`, checked locally first).
struct PlanLimitError: Error, LocalizedError {
    enum Kind { case accounts, categories, recurring }

    let kind: Kind

    var errorDescription: String? {
        switch kind {
        case .accounts:
            String(
                localized:
                    "Paket gratis dibatasi 4 akun aktif. Arsipkan akun lain atau tingkatkan ke Premium."
            )
        case .categories:
            String(
                localized:
                    "Paket gratis dibatasi 5 kategori buatan sendiri. Hapus salah satu atau tingkatkan ke Premium."
            )
        case .recurring:
            String(localized: "Transaksi berulang hanya untuk Premium.")
        }
    }
}
