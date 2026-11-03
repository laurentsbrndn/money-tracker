import Foundation
import Observation

/// Sync status, "Sync sekarang", and the "Perlu perhatian" list (APP_FLOWS Flow 11).
@Observable
@MainActor
final class SyncSettingsViewModel {
    private(set) var syncing = false
    var notice: String?
    var errorMessage: String?

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    var pendingCount: Int { container.syncStatus.pendingCount }
    var failed: [FailedChange] { container.syncStatus.failedChanges }
    var lastSyncAt: Date? { container.syncStatus.lastSyncAt }

    func syncNow() async {
        syncing = true
        let outcome = await container.scheduler.syncNow()
        syncing = false
        switch outcome {
        case .synced: notice = String(localized: "Sinkronisasi selesai.")
        case .offline: notice = String(localized: "Tidak ada koneksi.")
        case .needsLogin: notice = String(localized: "Masuk lagi untuk menyinkronkan.")
        case .failed, .skipped: notice = String(localized: "Sinkronisasi gagal. Akan dicoba lagi.")
        }
    }

    /// Opens the edit screen of the refused record so the user can fix the cause.
    func fix(_ change: FailedChange) {
        switch change.entity {
        case SyncEntities.accounts: container.router.push(.accountForm(id: change.recordId))
        case SyncEntities.categories:
            container.router.push(.categoryForm(id: change.recordId, type: nil))
        case SyncEntities.transactions: container.router.openTransaction(id: change.recordId)
        default: break
        }
    }

    func canFix(_ change: FailedChange) -> Bool {
        !change.isDelete
            && [SyncEntities.accounts, SyncEntities.categories, SyncEntities.transactions]
                .contains(change.entity)
    }

    func retry(_ change: FailedChange) async {
        do {
            try await container.failedChanges.retry(change)
            notice = String(localized: "Dikirim ulang.")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func discard(_ change: FailedChange) async {
        do {
            try await container.failedChanges.discard(change)
            notice = String(localized: "Perubahan dibuang.")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    static func entityLabel(_ entity: String) -> String {
        switch entity {
        case SyncEntities.accounts: String(localized: "Akun")
        case SyncEntities.categories: String(localized: "Kategori")
        case SyncEntities.transactions: String(localized: "Transaksi")
        case SyncEntities.balanceSnapshots: String(localized: "Saldo asli")
        case SyncEntities.userSettings: String(localized: "Pengaturan")
        case SyncEntities.budgetGoals: String(localized: "Budget")
        default: String(localized: "Transaksi berulang")
        }
    }

    static func reason(_ error: String) -> String {
        if error.hasPrefix("plan_limit") {
            return String(localized: "Melewati batas paket gratis.")
        }
        if error.hasPrefix("validation") { return String(localized: "Data tidak valid.") }
        if error.hasPrefix("reference_missing") {
            return String(localized: "Data terkait belum ada di server.")
        }
        if error.hasPrefix("forbidden") { return String(localized: "Tidak diizinkan.") }
        return String(localized: "Ditolak server.")
    }
}
