#if DEBUG
    import Foundation
    import GRDB

    /// Sample rows for previews. The `populated` data set is `01_monthly_basic` (BUSINESS_RULES
    /// §9.3) so the Dashboard shows the verified numbers; every figure on screen is still computed
    /// by `DomainRules` from these rows. Rows are `synced`, so the outbox stays empty.
    enum PreviewSampleData {
        static let userID = "preview-user"
        /// The fixture's `as_of`; previews pin "today" to it.
        static let today = CivilDate(year: 2026, month: 11, day: 30)

        static func date(_ text: String) -> CivilDate {
            guard let parsed = try? CivilDate(parsing: text) else { return today }
            return parsed
        }

        static func timestamp(_ text: String) -> Date {
            TimestampFormat.parse(text) ?? Date(timeIntervalSince1970: 0)
        }

        static func seed(_ db: Database, populated: Bool, variant: PreviewVariant) throws {
            let base = timestamp("2026-10-01T00:00:00.000Z")
            try setSyncFlags(db, now: timestamp("2026-11-30T12:00:00.000Z"))
            try UserSettingsRecord(
                id: userID, createdAt: base, updatedAt: base, deletedAt: nil, serverVersion: 1,
                syncStatus: "synced", syncError: nil, timezone: "Asia/Jakarta", currency: "IDR",
                weekStart: 1, theme: "system", dailyReminderTime: nil,
                reconcileReminderEnabled: true, budgetAlertEnabled: true,
                hideAmounts: variant == .hiddenAmounts
            ).insert(db)
            for category in categories(base) { try category.insert(db) }
            for account in accounts(base, populated: populated) { try account.insert(db) }
            guard populated else { return }
            for transaction in transactions() { try transaction.insert(db) }
            for snapshot in snapshots() { try snapshot.insert(db) }
            try BudgetGoalRecord(
                id: "goal-2026-10", createdAt: base, updatedAt: base, deletedAt: nil,
                serverVersion: 1, syncStatus: "synced", syncError: nil,
                effectiveMonth: date("2026-10-01"), needsPct: 50, wantsPct: 30, savingsPct: 20,
                plannedIncome: nil
            ).insert(db)
            switch variant {
            case .attention: try markFailed(db)
            case .pending: try queueOutbox(db)
            default: break
            }
        }

        private static func setSyncFlags(_ db: Database, now: Date) throws {
            try db.setSyncState(SyncStateKey.userID, userID)
            try db.setSyncState(SyncStateKey.initialSyncDone, "true")
            try db.setSyncState(SyncStateKey.setupPending, "false")
            try db.setSyncState(SyncStateKey.deviceID, "preview-device")
            try db.setSyncState(SyncStateKey.lastSyncAt, TimestampFormat.format(now))
        }

        // MARK: - Accounts

        private static func accounts(_ base: Date, populated: Bool) -> [AccountRecord] {
            func account(
                _ id: String, _ name: String, _ type: String, provider: String?, opening: Int64,
                order: Int, inTotal: Bool = true
            ) -> AccountRecord {
                AccountRecord(
                    id: id, createdAt: base, updatedAt: base, deletedAt: nil, serverVersion: 1,
                    syncStatus: "synced", syncError: nil, name: name, type: type,
                    providerKey: provider, currency: "IDR", openingBalance: opening,
                    openingDate: date("2026-10-01"), includeInTotal: inTotal, sortOrder: order,
                    archivedAt: nil)
            }
            guard populated else {
                return [account("acc-cash", "Cash", "cash", provider: nil, opening: 0, order: 0)]
            }
            return [
                account("acc-cash", "Cash", "cash", provider: nil, opening: 500_000, order: 0),
                account("acc-bca", "BCA", "bank", provider: "bca", opening: 5_000_000, order: 1),
                account(
                    "acc-jago", "Jago Tabungan", "savings", provider: "jago",
                    opening: 2_000_000, order: 2),
                // No rows and a zero opening balance: shown in lists, invisible in every total.
                account(
                    "acc-mandiri", "Mandiri", "bank", provider: "mandiri", opening: 0, order: 3),
                account("acc-gopay", "GoPay", "e_wallet", provider: "gopay", opening: 0, order: 4),
            ]
        }

        // MARK: - Categories

        private static func categories(_ base: Date) -> [CategoryRecord] {
            var order = 0
            func category(
                _ id: String, _ type: String, _ name: String, _ icon: String, _ color: String,
                _ allocation: String?
            ) -> CategoryRecord {
                order += 1
                return CategoryRecord(
                    id: id, createdAt: base, updatedAt: base, deletedAt: nil, serverVersion: 1,
                    syncStatus: "synced", syncError: nil, type: type, name: name, icon: icon,
                    color: color, defaultAllocation: allocation, sortOrder: order,
                    isDefault: true, isHidden: false, archivedAt: nil)
            }
            return [
                category("cat-food", "expense", "Makan & Minum", "food", "#F59E0B", "needs"),
                category(
                    "cat-transport", "expense", "Transportasi", "transport", "#3B82F6", "needs"),
                category("cat-home", "expense", "Tempat Tinggal", "home", "#8B5CF6", "needs"),
                category("cat-bill", "expense", "Tagihan", "bill", "#06B6D4", "needs"),
                category("cat-health", "expense", "Kesehatan", "health", "#EF4444", "needs"),
                category("cat-fee", "expense", "Biaya Admin", "fee", "#9CA3AF", "needs"),
                category("cat-shopping", "expense", "Belanja", "shopping", "#EC4899", "wants"),
                category("cat-fun", "expense", "Hiburan", "entertainment", "#F97316", "wants"),
                category("cat-sub", "expense", "Langganan", "subscription", "#6366F1", "wants"),
                category("cat-other", "expense", "Lainnya", "other", "#9CA3AF", "wants"),
                category("cat-salary", "income", "Gaji", "salary", "#10B981", nil),
                category("cat-freelance", "income", "Freelance", "freelance", "#14B8A6", nil),
                category("cat-bonus", "income", "Bonus", "bonus", "#22C55E", nil),
            ]
        }

        // MARK: - Fixture rows

        private static func transactions() -> [TransactionRecord] {
            func row(
                _ id: String, _ type: String, _ day: String, _ amount: Int64, from account: String,
                to: String? = nil, category: String? = nil, allocation: String? = nil,
                linked: String? = nil, note: String, status: String = "posted",
                deleted: Bool = false
            ) -> TransactionRecord {
                let stamp = timestamp("\(day)T05:00:00.000Z")
                return TransactionRecord(
                    id: id, createdAt: stamp, updatedAt: stamp,
                    deletedAt: deleted ? timestamp("2026-11-13T02:00:00.000Z") : nil,
                    serverVersion: 1, syncStatus: "synced", syncError: nil, type: type,
                    status: status, transactionDate: date(day), amount: amount, currency: "IDR",
                    accountId: account, toAccountId: to, categoryId: category,
                    allocation: allocation, source: nil, note: note, linkedTransactionId: linked,
                    recurringRuleId: nil)
            }
            return [
                row(
                    "t0a", "income", "2026-10-25", 8_000_000, from: "acc-bca",
                    category: "cat-salary",
                    note: "Gaji Oktober"),
                row(
                    "t0b", "expense", "2026-10-26", 1_500_000, from: "acc-bca",
                    category: "cat-home",
                    allocation: "needs", note: "Kos Oktober"),
                row(
                    "t1", "expense", "2026-11-03", 50_000, from: "acc-cash", category: "cat-food",
                    allocation: "needs", note: "Makan"),
                row(
                    "t2", "expense", "2026-11-10", 300_000, from: "acc-bca", category: "cat-fun",
                    allocation: "wants", note: "Hiburan"),
                row(
                    "t3", "income", "2026-11-25", 8_000_000, from: "acc-bca",
                    category: "cat-salary",
                    note: "Gaji"),
                row(
                    "t4", "transfer", "2026-11-25", 1_000_000, from: "acc-bca", to: "acc-jago",
                    note: "Menabung"),
                row(
                    "t5", "expense", "2026-11-25", 2_500, from: "acc-bca", category: "cat-fee",
                    allocation: "needs", linked: "t4", note: "Biaya admin"),
                row(
                    "t6", "expense", "2026-11-26", 1_500_000, from: "acc-bca", category: "cat-home",
                    allocation: "needs", note: "Kos"),
                row(
                    "t7", "transfer", "2026-11-28", 200_000, from: "acc-jago", to: "acc-cash",
                    note: "Tarik tabungan"),
                // Not counted: deleted, and still waiting for confirmation.
                row(
                    "t8", "expense", "2026-11-12", 999_999, from: "acc-cash", category: "cat-fun",
                    allocation: "wants", note: "Terhapus", deleted: true),
                row(
                    "t9", "expense", "2026-11-20", 100_000, from: "acc-bca", category: "cat-fun",
                    allocation: "wants", note: "Menunggu konfirmasi",
                    status: "pending_confirmation"),
            ]
        }

        private static func snapshots() -> [BalanceSnapshotRecord] {
            func snapshot(
                _ id: String, _ account: String, _ day: String, _ amount: Int64, _ at: String
            )
                -> BalanceSnapshotRecord
            {
                let stamp = timestamp(at)
                return BalanceSnapshotRecord(
                    id: id, createdAt: stamp, updatedAt: stamp, deletedAt: nil, serverVersion: 1,
                    syncStatus: "synced", syncError: nil, accountId: account,
                    snapshotDate: date(day), amount: amount, note: nil)
            }
            return [
                snapshot("s-cash-0", "acc-cash", "2026-10-01", 500_000, "2026-10-01T00:00:00.000Z"),
                snapshot("s-bca-0", "acc-bca", "2026-10-01", 5_000_000, "2026-10-01T00:00:00.000Z"),
                snapshot(
                    "s-jago-0", "acc-jago", "2026-10-01", 2_000_000, "2026-10-01T00:00:00.000Z"),
                snapshot("s-cash-1", "acc-cash", "2026-11-30", 600_000, "2026-11-30T12:00:00.000Z"),
                snapshot(
                    "s-bca-1", "acc-bca", "2026-11-28", 16_697_500, "2026-11-28T12:00:00.000Z"),
            ]
        }

        // MARK: - Sync state variants

        /// Two rows the server refused for good ("Perlu perhatian").
        private static func markFailed(_ db: Database) throws {
            if var transaction = try TransactionRecord.fetchOne(db, key: "t2") {
                transaction.syncStatus = "failed"
                transaction.syncError = "validation_failed: kategori tidak ditemukan"
                try transaction.update(db)
            }
            if var account = try AccountRecord.fetchOne(db, key: "acc-gopay") {
                account.syncStatus = "failed"
                account.syncError = "plan_limit_exceeded: batas akun paket gratis tercapai"
                try account.update(db)
            }
        }

        /// Three local changes waiting to be sent ("Menunggu sync").
        private static func queueOutbox(_ db: Database) throws {
            let now = timestamp("2026-11-30T11:00:00.000Z")
            for id in ["t1", "t2", "t3"] {
                var entry = OutboxRecord(
                    seq: nil, entity: SyncEntities.transactions, recordId: id, op: "upsert",
                    payload: "{}", updatedAt: now, batchId: nil, attempts: 0, nextAttemptAt: nil,
                    lastError: nil, createdAt: now)
                try entry.insert(db)
            }
        }
    }
#endif
