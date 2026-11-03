import Foundation

/// Rows ↔ the snake_case JSON of SYNC_PROTOCOL §4. Rows are always sent whole, every nullable
/// key present as `null` when empty. Server-only columns (`user_id`, `server_version`,
/// `server_updated_at`) and local-only columns (`sync_status`, `sync_error`) are never sent.
enum EntityCodec {
    /// Reads typed values out of a row, failing the whole row on a missing required key.
    struct Reader {
        let json: JSONValue

        func string(_ key: String) throws -> String {
            guard let value = json[key]?.stringValue else { throw missing(key) }
            return value
        }

        func optionalString(_ key: String) -> String? { json[key]?.stringValue }

        func int(_ key: String) throws -> Int64 {
            guard let value = json[key]?.intValue else { throw missing(key) }
            return value
        }

        func optionalInt(_ key: String) -> Int64? { json[key]?.intValue }

        func bool(_ key: String) throws -> Bool {
            guard let value = json[key]?.boolValue else { throw missing(key) }
            return value
        }

        func bool(_ key: String, default fallback: Bool) -> Bool {
            json[key]?.boolValue ?? fallback
        }

        func timestamp(_ key: String) throws -> Date {
            guard let text = json[key]?.stringValue, let date = TimestampFormat.parse(text) else {
                throw missing(key)
            }
            return date
        }

        func optionalTimestamp(_ key: String) -> Date? {
            json[key]?.stringValue.flatMap(TimestampFormat.parse)
        }

        func date(_ key: String) throws -> CivilDate {
            guard let text = json[key]?.stringValue, let date = try? CivilDate(parsing: text) else {
                throw missing(key)
            }
            return date
        }

        func optionalDate(_ key: String) -> CivilDate? {
            json[key]?.stringValue.flatMap { try? CivilDate(parsing: $0) }
        }

        private func missing(_ key: String) -> WireFormatError {
            WireFormatError(message: "missing or invalid \(key)")
        }
    }

    static func ts(_ date: Date?) -> JSONValue {
        date.map { .string(TimestampFormat.format($0)) } ?? .null
    }

    static func string(_ value: String?) -> JSONValue { value.map { .string($0) } ?? .null }

    static func int(_ value: Int64?) -> JSONValue { value.map { .int($0) } ?? .null }

    static func civil(_ value: CivilDate?) -> JSONValue {
        value.map { .string($0.description) } ?? .null
    }
}

extension UserSettingsRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "timezone": .string(timezone), "currency": .string(currency),
            "week_start": .int(Int64(weekStart)), "theme": .string(theme),
            "daily_reminder_time": EntityCodec.string(dailyReminderTime),
            "reconcile_reminder_enabled": .bool(reconcileReminderEnabled),
            "budget_alert_enabled": .bool(budgetAlertEnabled), "hide_amounts": .bool(hideAmounts),
            "created_at": EntityCodec.ts(createdAt), "updated_at": EntityCodec.ts(updatedAt),
            "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            timezone: try r.string("timezone"), currency: r.optionalString("currency") ?? "IDR",
            weekStart: Int(try r.int("week_start")), theme: try r.string("theme"),
            dailyReminderTime: r.optionalString("daily_reminder_time"),
            reconcileReminderEnabled: try r.bool("reconcile_reminder_enabled"),
            budgetAlertEnabled: try r.bool("budget_alert_enabled"),
            hideAmounts: try r.bool("hide_amounts"))
    }
}

extension CategoryRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "type": .string(type), "name": .string(name), "icon": .string(icon),
            "color": .string(color), "default_allocation": EntityCodec.string(defaultAllocation),
            "sort_order": .int(Int64(sortOrder)), "is_default": .bool(isDefault),
            "is_hidden": .bool(isHidden), "archived_at": EntityCodec.ts(archivedAt),
            "created_at": EntityCodec.ts(createdAt), "updated_at": EntityCodec.ts(updatedAt),
            "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            type: try r.string("type"), name: try r.string("name"), icon: try r.string("icon"),
            color: try r.string("color"), defaultAllocation: r.optionalString("default_allocation"),
            sortOrder: Int(try r.int("sort_order")), isDefault: try r.bool("is_default"),
            isHidden: r.bool("is_hidden", default: false),
            archivedAt: r.optionalTimestamp("archived_at"))
    }
}

extension AccountRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "name": .string(name), "type": .string(type),
            "provider_key": EntityCodec.string(providerKey), "currency": .string(currency),
            "opening_balance": .int(openingBalance), "opening_date": EntityCodec.civil(openingDate),
            "include_in_total": .bool(includeInTotal), "sort_order": .int(Int64(sortOrder)),
            "archived_at": EntityCodec.ts(archivedAt), "created_at": EntityCodec.ts(createdAt),
            "updated_at": EntityCodec.ts(updatedAt), "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            name: try r.string("name"), type: try r.string("type"),
            providerKey: r.optionalString("provider_key"),
            currency: r.optionalString("currency") ?? "IDR",
            openingBalance: try r.int("opening_balance"), openingDate: try r.date("opening_date"),
            includeInTotal: r.bool("include_in_total", default: true),
            sortOrder: Int(try r.int("sort_order")), archivedAt: r.optionalTimestamp("archived_at"))
    }
}

extension BalanceSnapshotRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "account_id": .string(accountId),
            "snapshot_date": EntityCodec.civil(snapshotDate), "amount": .int(amount),
            "note": EntityCodec.string(note), "created_at": EntityCodec.ts(createdAt),
            "updated_at": EntityCodec.ts(updatedAt), "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            accountId: try r.string("account_id"), snapshotDate: try r.date("snapshot_date"),
            amount: try r.int("amount"), note: r.optionalString("note"))
    }
}

extension TransactionRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "type": .string(type), "status": .string(status),
            "transaction_date": EntityCodec.civil(transactionDate), "amount": .int(amount),
            "currency": .string(currency), "account_id": .string(accountId),
            "to_account_id": EntityCodec.string(toAccountId),
            "category_id": EntityCodec.string(categoryId),
            "allocation": EntityCodec.string(allocation), "source": EntityCodec.string(source),
            "note": EntityCodec.string(note),
            "linked_transaction_id": EntityCodec.string(linkedTransactionId),
            "recurring_rule_id": EntityCodec.string(recurringRuleId),
            "created_at": EntityCodec.ts(createdAt), "updated_at": EntityCodec.ts(updatedAt),
            "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            type: try r.string("type"), status: r.optionalString("status") ?? "posted",
            transactionDate: try r.date("transaction_date"), amount: try r.int("amount"),
            currency: r.optionalString("currency") ?? "IDR", accountId: try r.string("account_id"),
            toAccountId: r.optionalString("to_account_id"),
            categoryId: r.optionalString("category_id"), allocation: r.optionalString("allocation"),
            source: r.optionalString("source"), note: r.optionalString("note"),
            linkedTransactionId: r.optionalString("linked_transaction_id"),
            recurringRuleId: r.optionalString("recurring_rule_id"))
    }
}

extension RecurringRuleRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "type": .string(type), "amount": .int(amount),
            "account_id": .string(accountId), "to_account_id": EntityCodec.string(toAccountId),
            "category_id": EntityCodec.string(categoryId),
            "allocation": EntityCodec.string(allocation), "source": EntityCodec.string(source),
            "note": EntityCodec.string(note), "frequency": .string(frequency),
            "interval_count": .int(Int64(intervalCount)),
            "day_of_week": EntityCodec.int(dayOfWeek.map(Int64.init)),
            "day_of_month": EntityCodec.int(dayOfMonth.map(Int64.init)),
            "month_of_year": EntityCodec.int(monthOfYear.map(Int64.init)),
            "start_date": EntityCodec.civil(startDate), "end_date": EntityCodec.civil(endDate),
            "mode": .string(mode), "is_paused": .bool(isPaused),
            "last_generated_date": EntityCodec.civil(lastGeneratedDate),
            "created_at": EntityCodec.ts(createdAt), "updated_at": EntityCodec.ts(updatedAt),
            "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            type: try r.string("type"), amount: try r.int("amount"),
            accountId: try r.string("account_id"), toAccountId: r.optionalString("to_account_id"),
            categoryId: r.optionalString("category_id"), allocation: r.optionalString("allocation"),
            source: r.optionalString("source"), note: r.optionalString("note"),
            frequency: try r.string("frequency"),
            intervalCount: Int(r.optionalInt("interval_count") ?? 1),
            dayOfWeek: r.optionalInt("day_of_week").map(Int.init),
            dayOfMonth: r.optionalInt("day_of_month").map(Int.init),
            monthOfYear: r.optionalInt("month_of_year").map(Int.init),
            startDate: try r.date("start_date"), endDate: r.optionalDate("end_date"),
            mode: try r.string("mode"), isPaused: r.bool("is_paused", default: false),
            lastGeneratedDate: r.optionalDate("last_generated_date"))
    }
}

extension BudgetGoalRecord {
    var wireJSON: JSONValue {
        .object([
            "id": .string(id), "effective_month": EntityCodec.civil(effectiveMonth),
            "needs_pct": .int(Int64(needsPct)), "wants_pct": .int(Int64(wantsPct)),
            "savings_pct": .int(Int64(savingsPct)),
            "planned_income": EntityCodec.int(plannedIncome),
            "created_at": EntityCodec.ts(createdAt), "updated_at": EntityCodec.ts(updatedAt),
            "deleted_at": EntityCodec.ts(deletedAt),
        ])
    }

    init(wire: JSONValue, serverVersion: Int64) throws {
        let r = EntityCodec.Reader(json: wire)
        self.init(
            id: try r.string("id"), createdAt: try r.timestamp("created_at"),
            updatedAt: try r.timestamp("updated_at"), deletedAt: r.optionalTimestamp("deleted_at"),
            serverVersion: serverVersion, syncStatus: "synced", syncError: nil,
            effectiveMonth: try r.date("effective_month"), needsPct: Int(try r.int("needs_pct")),
            wantsPct: Int(try r.int("wants_pct")), savingsPct: Int(try r.int("savings_pct")),
            plannedIncome: r.optionalInt("planned_income"))
    }
}
