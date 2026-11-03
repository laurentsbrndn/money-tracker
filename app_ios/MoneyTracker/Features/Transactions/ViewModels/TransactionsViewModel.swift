import Observation

/// The history list (APP_FLOWS Flow 4): grouped by day, filter, search, paging, delete with undo,
/// duplicate.
@Observable
@MainActor
final class TransactionsViewModel {
    static let pageSize = 50

    var filter = TransactionFilter()
    /// What the search field shows; copied into `filter.query` after a short pause.
    var searchText = ""
    private(set) var limit = TransactionsViewModel.pageSize
    private(set) var rows: [TransactionRecord] = []
    private(set) var loaded = false
    private(set) var undoable: [TransactionRecord]?
    var errorMessage: String?
    var notice: String?

    private let repository: TransactionsRepository
    private var searchTask: Task<Void, Never>?
    private var undoTask: Task<Void, Never>?

    init(container: AppContainer) {
        repository = container.transactions
    }

    var groups: [DayGroup] { DayGroup.group(rows, asOf: UserClock.today()) }

    /// More rows may exist beyond the current page.
    var hasMore: Bool { rows.count >= limit }

    struct ObservationKey: Hashable {
        let filter: TransactionFilter
        let limit: Int
    }

    var observationKey: ObservationKey { ObservationKey(filter: filter, limit: limit) }

    func observe() async {
        await forEachValue(repository.observe(filter, limit: limit)) {
            self.rows = $0
            self.loaded = true
        }
    }

    func loadMore() {
        guard hasMore else { return }
        limit += Self.pageSize
    }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            if self.filter.query != self.searchText {
                self.filter.query = self.searchText
                self.limit = Self.pageSize
            }
        }
    }

    func apply(_ newFilter: TransactionFilter) {
        filter = newFilter
        searchText = newFilter.query
        limit = Self.pageSize
    }

    func clearFilters() {
        apply(TransactionFilter())
    }

    func delete(_ row: TransactionRecord) async {
        do {
            let removed = try await repository.delete(row.id)
            guard !removed.isEmpty else { return }
            undoable = removed
            undoTask?.cancel()
            undoTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                if !Task.isCancelled { self?.undoable = nil }
            }
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func undoDelete() async {
        guard let removed = undoable else { return }
        undoable = nil
        undoTask?.cancel()
        do { try await repository.restore(removed) } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }

    func duplicate(_ row: TransactionRecord) async {
        do {
            if try await repository.duplicate(row.id) != nil {
                notice = String(localized: "Transaksi diduplikat dengan tanggal hari ini")
            }
        } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
