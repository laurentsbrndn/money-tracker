import Foundation

/// Reads the rows of an export from the local database (offline-first, no endpoint). Only
/// posted, live transactions come back: pending confirmations and tombstones are never exported.
struct ExportRepository: Sendable {
    let database: AppDatabase

    func loadRows(_ period: ExportPeriod) async throws -> [ExportRow] {
        try await database.pool.read { db in
            let accounts = Dictionary(
                uniqueKeysWithValues: try db.liveAccounts().map { ($0.id, $0.name) })
            let categories = Dictionary(
                uniqueKeysWithValues: try db.liveCategories().map { ($0.id, $0.name) })
            return try db.postedTransactions(from: period.from, to: period.to).map { row in
                ExportRow(
                    date: row.transactionDate,
                    type: TransactionType(rawValue: row.type) ?? .expense, amount: row.amount,
                    accountName: accounts[row.accountId] ?? "-",
                    toAccountName: row.toAccountId.map { accounts[$0] ?? "-" },
                    categoryName: row.categoryId.flatMap { categories[$0] }, note: row.note)
            }
        }
    }
}
