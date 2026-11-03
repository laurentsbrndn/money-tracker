import Foundation
import GRDB

/// Builds the local notification schedule from the database and shows budget warnings (APP_FLOWS
/// "Notifikasi lokal"). It reads the database directly, so the same code runs while the app is
/// open and at the end of a background refresh.
///
/// Every refresh is serialised: two overlapping runs would otherwise cancel each other's
/// schedule or announce one warning twice.
actor NotificationScheduler {
    private let database: AppDatabase
    private let service: NotificationService
    /// Whether a user is signed in (the local data may still be used while a login is needed).
    private let isSignedIn: @Sendable () async -> Bool
    private var tail: Task<Void, Never>?

    init(
        database: AppDatabase, service: NotificationService,
        isSignedIn: @escaping @Sendable () async -> Bool
    ) {
        self.database = database
        self.service = service
        self.isSignedIn = isSignedIn
    }

    /// Rebuilds the scheduled notifications for the current settings and data, then announces
    /// any budget threshold that was crossed.
    func refresh(now: Date = Date()) async {
        let previous = tail
        let task = Task {
            await previous?.value
            await self.run(now: now)
        }
        tail = task
        await task.value
    }

    /// Removes everything this scheduler may have scheduled (sign-out).
    func cancelAll() async {
        let previous = tail
        let task = Task {
            await previous?.value
            await self.service.cancelAll()
        }
        tail = task
        await task.value
    }

    private func run(now: Date) async {
        // No notifications while the account is still being set up.
        guard await isSignedIn(),
            let flags = try? await database.pool.read({ db in
                (
                    try db.syncState(SyncStateKey.initialSyncDone),
                    try db.syncState(SyncStateKey.setupPending)
                )
            }), flags.0 == "true", flags.1 != "true"
        else { return }
        do {
            try await reschedule(now: now)
            try await announceBudget(now: now)
        } catch {
            // A failed refresh is retried by the next change or by the app coming back.
        }
    }

    private struct Inputs: Sendable {
        var settings: UserSettingsRecord
        var accounts: [AccountRecord]
        var snapshots: [BalanceSnapshotRecord]
        var hasTransactionToday: Bool
    }

    private func reschedule(now: Date) async throws {
        guard
            let settings = try await database.pool.read({
                try UserSettingsRecord.filter(Column("deleted_at") == nil).fetchOne($0)
            })
        else { return }
        let zone = UserClock.zone(for: settings.timezone)
        let today = UserClock.civilDate(of: now, in: zone)
        let inputs = try await database.pool.read { db in
            Inputs(
                settings: settings, accounts: try db.liveAccounts(),
                snapshots: try db.allSnapshots(),
                hasTransactionToday: try db.hasPostedTransaction(on: today))
        }
        let snapshots = inputs.snapshots.map(\.domain)
        var snapshotDates: [CivilDate?] = []
        for account in inputs.accounts where DomainRules.isInTotal(account.domain) {
            // A missing snapshot stays an entry: that account is stale already.
            snapshotDates.append(
                DomainRules.latestSnapshot(snapshots, accountID: account.id, asOf: today)?.date)
        }

        let plan = NotificationPlan.plan(
            prefs: NotificationPlan.Prefs(
                dailyReminderTime: settings.dailyReminderTime,
                reconcileEnabled: settings.reconcileReminderEnabled,
                budgetAlertEnabled: settings.budgetAlertEnabled),
            today: today, nowMinutes: UserClock.minutesOfDay(of: now, in: zone),
            hasTransactionToday: inputs.hasTransactionToday, snapshotDates: snapshotDates)

        await service.cancelPlanned()
        for planned in plan {
            let text = Self.text(for: planned)
            await service.schedule(planned, userZone: zone, title: text.title, body: text.body)
        }
    }

    private static func text(for planned: PlannedNotification) -> (title: String, body: String) {
        switch planned.kind {
        case .daily:
            return (
                String(localized: "Catat transaksi hari ini"),
                String(localized: "Sudah mencatat pengeluaran dan pemasukanmu hari ini?")
            )
        case .reconcileMonthEnd:
            return (
                String(localized: "Waktunya cocokkan saldo"),
                String(localized: "Samakan catatanmu dengan saldo asli rekening dan uang tunai.")
            )
        case .reconcileStale:
            return (
                String(localized: "Saldo aktual perlu diperbarui"),
                String(localized: "Ada akun yang saldo aslinya belum dicek lebih dari 7 hari.")
            )
        case .monthEvaluation:
            // The evaluation covers the month that just ended.
            let ended = YearMonth(containing: planned.date).adding(months: -1)
            return (
                String(localized: "Evaluasi budget bulan lalu"),
                String(localized: "Lihat bagaimana needs, wants, dan savings \(ended.titleText).")
            )
        }
    }

    // MARK: - Budget warnings

    private func announceBudget(now: Date) async throws {
        guard
            let settings = try await database.pool.read({
                try UserSettingsRecord.filter(Column("deleted_at") == nil).fetchOne($0)
            }), settings.budgetAlertEnabled
        else { return }
        let zone = UserClock.zone(for: settings.timezone)
        let today = UserClock.civilDate(of: now, in: zone)
        let month = YearMonth(containing: today)

        let (accounts, transactions, goals, sentRaw) = try await database.pool.read { db in
            (
                try db.liveAccounts().map(\.domain), try db.allTransactions().map(\.domain),
                try db.liveBudgetGoals().map(\.domain),
                try db.syncState(SyncStateKey.budgetAlertsSent)
            )
        }
        guard let goal = DomainRules.effectiveGoal(goals, month: month) else { return }
        let budget = DomainRules.computeBudget(
            accounts: accounts, transactions: transactions, goal: goal, month: month, asOf: today)
        let sent = Set((sentRaw ?? "").split(separator: "\n").map(String.init))
        let plan = BudgetAlertPolicy.plan(month: month, budget: budget, alreadyAnnounced: sent)
        guard !plan.alerts.isEmpty else { return }
        // Without the permission nothing can be shown, so do not use up the once-per-month
        // announcement.
        guard await service.areEnabled() else { return }

        // Keep only this month's keys, so the list cannot grow forever.
        let remembered = sent.union(plan.keysToRemember).filter { $0.hasPrefix("\(month)|") }
        try await database.setSyncState(
            SyncStateKey.budgetAlertsSent, remembered.sorted().joined(separator: "\n"))

        for alert in plan.alerts {
            let name = Self.name(of: alert.allocation)
            let limit = alert.level >= budgetLimitPercent
            let title =
                limit
                ? String(localized: "\(name) melewati goal")
                : String(localized: "\(name) hampir melewati goal")
            // With "sembunyikan nominal" on, the text carries no amount at all.
            let body =
                settings.hideAmounts
                ? String(localized: "\(name) sudah mencapai \(alert.level)% dari goal bulan ini.")
                : String(
                    localized:
                        "\(name): \(MoneyFormatter.rupiah(alert.actual)) dari goal \(MoneyFormatter.rupiah(alert.goalAmount)) (\(alert.level)% dari goal bulan ini)."
                )
            await service.showNow(
                identifier: "mt.budget.\(month).\(alert.allocation.rawValue).\(alert.level)",
                title: title, body: body, payload: NotificationPayload.budget(month: month))
        }
    }

    private static func name(of allocation: Allocation) -> String {
        switch allocation {
        case .needs: String(localized: "Needs")
        case .wants: String(localized: "Wants")
        case .savings: String(localized: "Savings")
        }
    }
}
