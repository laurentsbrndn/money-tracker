import Observation

/// "Menunggu konfirmasi" (APP_FLOWS Flow 4 step 4): the transactions of `confirm` rules.
/// "Catat" records one as it is (tapping it first lets the amount and date change); "Lewati"
/// deletes it.
@Observable
@MainActor
final class PendingConfirmationViewModel {
    private(set) var pending: [TransactionRecord] = []
    var errorMessage: String?
    var notice: String?

    private let repository: TransactionsRepository

    init(container: AppContainer) {
        repository = container.transactions
    }

    func observe() async {
        await forEachValue(repository.observePending()) { self.pending = $0 }
    }

    func record(_ row: TransactionRecord) async {
        do {
            try await repository.confirm(row.id)
            notice = String(localized: "Transaksi dicatat")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func skip(_ row: TransactionRecord) async {
        do {
            _ = try await repository.delete(row.id)
            notice = String(localized: "Transaksi dilewati")
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
