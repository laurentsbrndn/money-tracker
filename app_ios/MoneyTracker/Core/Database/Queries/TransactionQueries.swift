import GRDB

extension Database {
    func transaction(id: String) throws -> TransactionRecord? {
        try TransactionRecord.fetchOne(self, key: id)
    }

    /// Live fee expenses linked to a transfer.
    func linkedTransactions(of transferId: String) throws -> [TransactionRecord] {
        try TransactionRecord
            .filter(Column("deleted_at") == nil && Column("linked_transaction_id") == transferId)
            .fetchAll(self)
    }

    /// Live transactions that still reference the account (as source or destination): such an
    /// account can only be archived (BUSINESS_RULES §6).
    func transactionCount(accountId: String) throws -> Int {
        try TransactionRecord
            .filter(
                Column("deleted_at") == nil
                    && (Column("account_id") == accountId || Column("to_account_id") == accountId)
            ).fetchCount(self)
    }

    func transactionCount(categoryId: String) throws -> Int {
        try TransactionRecord
            .filter(Column("deleted_at") == nil && Column("category_id") == categoryId).fetchCount(
                self)
    }

    /// The account used by the most recent transaction of `type`: the default pick in the entry
    /// form (APP_FLOWS Flow 3).
    func lastAccountId(type: String) throws -> String? {
        try TransactionRecord.filter(Column("deleted_at") == nil && Column("type") == type)
            .order(Column("created_at").desc).fetchOne(self)?.accountId
    }

    /// Whether a posted transaction dated `date` exists (the daily reminder is skipped then).
    func hasPostedTransaction(on date: CivilDate) throws -> Bool {
        try TransactionRecord
            .filter(
                Column("deleted_at") == nil && Column("status") == "posted"
                    && Column("transaction_date") == date
            ).fetchCount(self) > 0
    }

    /// Every live transaction; the balance formulas need the full history.
    func allTransactions() throws -> [TransactionRecord] {
        try TransactionRecord.filter(Column("deleted_at") == nil).fetchAll(self)
    }

    /// Live, posted rows for the export, oldest first. A nil bound is open; pending
    /// confirmations and tombstones never come back.
    func postedTransactions(from: CivilDate?, to: CivilDate?) throws -> [TransactionRecord] {
        var request = TransactionRecord.filter(
            Column("deleted_at") == nil && Column("status") == TransactionStatus.posted.rawValue)
        if let from { request = request.filter(Column("transaction_date") >= from) }
        if let to { request = request.filter(Column("transaction_date") <= to) }
        return try request.order(Column("transaction_date").asc, Column("created_at").asc)
            .fetchAll(self)
    }

    /// Recent distinct income sources, for suggestions.
    func recentSources(limit: Int = 8) throws -> [String] {
        let rows =
            try TransactionRecord
            .filter(
                Column("deleted_at") == nil && Column("type") == "income" && Column("source") != nil
            ).order(Column("created_at").desc).limit(60).fetchAll(self)
        var seen: [String] = []
        for row in rows {
            let source = (row.source ?? "").trimmingCharacters(in: .whitespaces)
            if !source.isEmpty && !seen.contains(source) {
                seen.append(source)
                if seen.count == limit { break }
            }
        }
        return seen
    }

    /// Live transactions in the history list, newest first, `limit` rows (paged by growing the
    /// limit). Transactions waiting for confirmation are not in it: they have their own section
    /// and do not count yet.
    func filteredTransactions(_ filter: TransactionFilter, limit: Int) throws -> [TransactionRecord]
    {
        try Self.request(for: filter).limit(limit).fetchAll(self)
    }

    private static func request(for filter: TransactionFilter) -> QueryInterfaceRequest<
        TransactionRecord
    > {
        var request = TransactionRecord.filter(
            Column("deleted_at") == nil && Column("status") == TransactionStatus.posted.rawValue)
        if let type = filter.type { request = request.filter(Column("type") == type) }
        if let accountId = filter.accountId {
            request = request.filter(
                Column("account_id") == accountId || Column("to_account_id") == accountId)
        }
        if let categoryId = filter.categoryId {
            request = request.filter(Column("category_id") == categoryId)
        }
        if let allocation = filter.allocation {
            request = request.filter(Column("allocation") == allocation)
        }
        if let from = filter.from { request = request.filter(Column("transaction_date") >= from) }
        if let to = filter.to { request = request.filter(Column("transaction_date") <= to) }
        let text = filter.query.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(
                    of: "_", with: "\\_")
            let pattern = "%\(escaped)%"
            request = request.filter(
                Column("note").like(pattern, escape: "\\")
                    || Column("source").like(pattern, escape: "\\"))
        }
        return request.order(Column("transaction_date").desc, Column("created_at").desc)
    }
}

extension AppDatabase {
    func observeFilteredTransactions(_ filter: TransactionFilter, limit: Int)
        -> AsyncValueObservation<[TransactionRecord]>
    {
        ValueObservation.tracking { try $0.filteredTransactions(filter, limit: limit) }.values(
            in: pool)
    }

    /// Live transactions of one calendar month, newest first.
    func observeTransactions(in month: YearMonth) -> AsyncValueObservation<[TransactionRecord]> {
        ValueObservation.tracking { db in
            try TransactionRecord
                .filter(
                    Column("deleted_at") == nil && Column("status") == TransactionStatus.posted.rawValue
                        && Column("transaction_date") >= month.first
                        && Column("transaction_date") <= month.last
                ).order(Column("transaction_date").desc, Column("created_at").desc).fetchAll(db)
        }.values(in: pool)
    }

    /// Live transactions of `confirm` rules waiting to be recorded or skipped, oldest first.
    func observePendingTransactions() -> AsyncValueObservation<[TransactionRecord]> {
        ValueObservation.tracking { db in
            try TransactionRecord
                .filter(
                    Column("deleted_at") == nil
                        && Column("status") == TransactionStatus.pendingConfirmation.rawValue
                ).order(Column("transaction_date").asc, Column("created_at").asc).fetchAll(db)
        }.values(in: pool)
    }

    /// Every live transaction; the balance formulas need the full history.
    func observeAllTransactions() -> AsyncValueObservation<[TransactionRecord]> {
        ValueObservation.tracking { db in
            try TransactionRecord.filter(Column("deleted_at") == nil).fetchAll(db)
        }.values(in: pool)
    }
}
