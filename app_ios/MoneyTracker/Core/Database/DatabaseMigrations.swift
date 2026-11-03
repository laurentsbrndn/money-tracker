import GRDB

/// All local migrations live here, one `registerMigration` per version.
enum DatabaseMigrations {
    static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_init") { db in
            try db.create(table: "user_settings") { t in
                addSyncColumns(t)
                t.column("timezone", .text).notNull().defaults(to: "Asia/Jakarta")
                t.column("currency", .text).notNull().defaults(to: "IDR")
                t.column("week_start", .integer).notNull().defaults(to: 1)
                t.column("theme", .text).notNull().defaults(to: "system")
                t.column("daily_reminder_time", .text)
                t.column("reconcile_reminder_enabled", .boolean).notNull().defaults(to: true)
                t.column("budget_alert_enabled", .boolean).notNull().defaults(to: true)
                t.column("hide_amounts", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "categories") { t in
                addSyncColumns(t)
                t.column("type", .text).notNull()
                t.column("name", .text).notNull()
                t.column("icon", .text).notNull()
                t.column("color", .text).notNull()
                t.column("default_allocation", .text)
                t.column("sort_order", .integer).notNull()
                t.column("is_default", .boolean).notNull()
                t.column("is_hidden", .boolean).notNull().defaults(to: false)
                t.column("archived_at", .text)
            }
            try db.create(index: "categories_type", on: "categories", columns: ["type"])

            try db.create(table: "accounts") { t in
                addSyncColumns(t)
                t.column("name", .text).notNull()
                t.column("type", .text).notNull()
                t.column("provider_key", .text)
                t.column("currency", .text).notNull().defaults(to: "IDR")
                t.column("opening_balance", .integer).notNull()
                t.column("opening_date", .text).notNull()
                t.column("include_in_total", .boolean).notNull().defaults(to: true)
                t.column("sort_order", .integer).notNull()
                t.column("archived_at", .text)
            }

            try db.create(table: "balance_snapshots") { t in
                addSyncColumns(t)
                t.column("account_id", .text).notNull()
                t.column("snapshot_date", .text).notNull()
                t.column("amount", .integer).notNull()
                t.column("note", .text)
            }
            try db.create(
                index: "balance_snapshots_account_date", on: "balance_snapshots",
                columns: ["account_id", "snapshot_date"])

            try db.create(table: "transactions") { t in
                addSyncColumns(t)
                t.column("type", .text).notNull()
                t.column("status", .text).notNull().defaults(to: "posted")
                t.column("transaction_date", .text).notNull()
                t.column("amount", .integer).notNull()
                t.column("currency", .text).notNull().defaults(to: "IDR")
                t.column("account_id", .text).notNull()
                t.column("to_account_id", .text)
                t.column("category_id", .text)
                t.column("allocation", .text)
                t.column("source", .text)
                t.column("note", .text)
                t.column("linked_transaction_id", .text)
                t.column("recurring_rule_id", .text)
            }
            try db.create(
                index: "transactions_date", on: "transactions", columns: ["transaction_date"])
            try db.create(
                index: "transactions_account_date", on: "transactions",
                columns: ["account_id", "transaction_date"])
            try db.create(
                index: "transactions_to_account", on: "transactions", columns: ["to_account_id"])
            try db.create(
                index: "transactions_recurring_rule", on: "transactions",
                columns: ["recurring_rule_id"])

            try db.create(table: "recurring_rules") { t in
                addSyncColumns(t)
                t.column("type", .text).notNull()
                t.column("amount", .integer).notNull()
                t.column("account_id", .text).notNull()
                t.column("to_account_id", .text)
                t.column("category_id", .text)
                t.column("allocation", .text)
                t.column("source", .text)
                t.column("note", .text)
                t.column("frequency", .text).notNull()
                t.column("interval_count", .integer).notNull().defaults(to: 1)
                t.column("day_of_week", .integer)
                t.column("day_of_month", .integer)
                t.column("month_of_year", .integer)
                t.column("start_date", .text).notNull()
                t.column("end_date", .text)
                t.column("mode", .text).notNull()
                t.column("is_paused", .boolean).notNull().defaults(to: false)
                t.column("last_generated_date", .text)
            }

            try db.create(table: "budget_goals") { t in
                addSyncColumns(t)
                t.column("effective_month", .text).notNull()
                t.column("needs_pct", .integer).notNull()
                t.column("wants_pct", .integer).notNull()
                t.column("savings_pct", .integer).notNull()
                t.column("planned_income", .integer)
            }
            try db.create(
                index: "budget_goals_effective_month", on: "budget_goals",
                columns: ["effective_month"])

            try db.create(table: "outbox") { t in
                t.autoIncrementedPrimaryKey("seq")
                t.column("entity", .text).notNull()
                t.column("record_id", .text).notNull()
                t.column("op", .text).notNull()
                t.column("payload", .text).notNull().defaults(to: "")
                t.column("updated_at", .text).notNull()
                t.column("attempts", .integer).notNull().defaults(to: 0)
                t.column("next_attempt_at", .text)
                t.column("last_error", .text)
                t.column("created_at", .text).notNull()
            }

            try db.create(table: "sync_state") { t in
                t.primaryKey("key", .text)
                t.column("value", .text).notNull()
            }
        }

        return migrator
    }

    /// Columns shared by every synced entity table (DATA_MODEL §1.1 without the server-only
    /// columns, plus the local columns of SYNC_PROTOCOL §5.1).
    private static func addSyncColumns(_ t: TableDefinition) {
        t.primaryKey("id", .text)
        t.column("created_at", .text).notNull()
        t.column("updated_at", .text).notNull()
        t.column("deleted_at", .text)
        t.column("server_version", .integer)
        t.column("sync_status", .text).notNull().defaults(to: "pending")
    }
}
