import Foundation

/// Id ranges, one per kind. A notification's identifier is `NotificationPlan.identifier(for:)`;
/// the scheduler removes every pending request with the app prefix before it schedules again, so
/// a changed setting never leaves a stale notification and scheduling is idempotent.
enum NotificationPlan {
    static let dailyIDBase = 1000
    static let reconcileMonthEndIDBase = 2000
    static let reconcileStaleIDBase = 3000
    static let monthEvaluationIDBase = 4000

    /// How many days of daily reminders are scheduled ahead. iOS keeps at most 64 pending
    /// notifications per app; the whole plan is at most 14 + 3 + 4 + 3 = 24. The schedule is
    /// rebuilt whenever the app opens or its data changes, and by the background refresh, so this
    /// only bounds how long the reminders last without any run.
    static let dailyHorizonDays = 14
    static let monthEndHorizon = 3
    static let staleHorizon = 4
    static let monthEvaluationHorizon = 3

    static let reconcileHour = 20
    static let evaluationHour = 9

    /// Prefix of every pending notification this app schedules.
    static let identifierPrefix = "mt.plan."

    static func identifier(for id: Int) -> String { identifierPrefix + String(id) }

    /// The user settings the plan depends on.
    struct Prefs: Sendable, Equatable {
        /// `HH:MM`, or nil when the daily reminder is off.
        var dailyReminderTime: String?
        var reconcileEnabled: Bool
        var budgetAlertEnabled: Bool
    }

    /// Parses `HH:MM`; nil when malformed.
    static func parseReminderTime(_ value: String?) -> (hour: Int, minute: Int)? {
        guard let value, value.utf8.count == 5 else { return nil }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
            let hour = Int(parts[0]), let minute = Int(parts[1]),
            (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    /// A moment still ahead of "now" (strictly later than `nowMinutes` today).
    private static func isFuture(
        _ date: CivilDate, minutes: Int, today: CivilDate, nowMinutes: Int
    ) -> Bool {
        date > today || (date == today && minutes > nowMinutes)
    }

    /// The scheduled notifications of APP_FLOWS "Notifikasi lokal", from the user's settings and
    /// data.
    ///
    /// * Daily reminder at the chosen time for the next `dailyHorizonDays` days, except today's
    ///   when a posted transaction dated today already exists.
    /// * Reconcile reminder at 20:00 on the last day of the month, and every 7 days at 20:00
    ///   while an account is stale (anchored on the day the earliest account became stale).
    /// * Month evaluation at 09:00 on the 1st, opening the month that just ended.
    ///
    /// `snapshotDates` holds, for every account that counts towards the total, the date of its
    /// newest snapshot (nil when it has none). Budget warnings are not scheduled: they fire when
    /// a threshold is crossed (see `BudgetAlertPolicy`).
    static func plan(
        prefs: Prefs, today: CivilDate, nowMinutes: Int, hasTransactionToday: Bool,
        snapshotDates: [CivilDate?]
    ) -> [PlannedNotification] {
        var result: [PlannedNotification] = []

        if let reminder = parseReminderTime(prefs.dailyReminderTime) {
            let minutes = reminder.hour * 60 + reminder.minute
            for i in 0..<dailyHorizonDays {
                if i == 0 && (hasTransactionToday || minutes <= nowMinutes) { continue }
                result.append(
                    PlannedNotification(
                        id: dailyIDBase + i, kind: .daily, date: today.adding(days: i),
                        hour: reminder.hour, minute: reminder.minute,
                        payload: NotificationPayload.newTransaction))
            }
        }

        if prefs.reconcileEnabled {
            var monthEnds: [CivilDate] = []
            var k = 0
            while k < monthEndHorizon + 1 && monthEnds.count < monthEndHorizon {
                let end = YearMonth(containing: today).adding(months: k).last
                if isFuture(end, minutes: reconcileHour * 60, today: today, nowMinutes: nowMinutes)
                {
                    monthEnds.append(end)
                }
                k += 1
            }
            for (index, end) in monthEnds.enumerated() {
                result.append(
                    PlannedNotification(
                        id: reconcileMonthEndIDBase + index, kind: .reconcileMonthEnd, date: end,
                        hour: reconcileHour, minute: 0, payload: NotificationPayload.reconcile))
            }

            if !snapshotDates.isEmpty {
                // An account is stale once `asOf - snapshot > staleAfterDays`, i.e. from the day
                // after `snapshot + staleAfterDays`. No snapshot = stale already.
                var anchor: CivilDate?
                for snapshot in snapshotDates {
                    let staleFrom =
                        snapshot.map { $0.adding(days: DomainRules.staleAfterDays + 1) } ?? today
                    if anchor == nil || staleFrom < anchor! { anchor = staleFrom }
                }
                var added = 0
                var week = 0
                while let anchor, added < staleHorizon && week < 520 {
                    defer { week += 1 }
                    let date = anchor.adding(days: 7 * week)
                    if !isFuture(
                        date, minutes: reconcileHour * 60, today: today, nowMinutes: nowMinutes)
                        || monthEnds.contains(date)
                    {
                        continue
                    }
                    result.append(
                        PlannedNotification(
                            id: reconcileStaleIDBase + added, kind: .reconcileStale, date: date,
                            hour: reconcileHour, minute: 0, payload: NotificationPayload.reconcile))
                    added += 1
                }
            }
        }

        if prefs.budgetAlertEnabled {
            var index = 0
            var k = 0
            while k < monthEvaluationHorizon + 1 && index < monthEvaluationHorizon {
                let month = YearMonth(containing: today).adding(months: k)
                let date = month.first
                if isFuture(
                    date, minutes: evaluationHour * 60, today: today, nowMinutes: nowMinutes)
                {
                    result.append(
                        PlannedNotification(
                            id: monthEvaluationIDBase + index, kind: .monthEvaluation, date: date,
                            hour: evaluationHour, minute: 0,
                            payload: NotificationPayload.budget(month: month.adding(months: -1))))
                    index += 1
                }
                k += 1
            }
        }
        return result
    }
}

/// The `userInfo`-free payload strings of notifications (the route opened on a tap).
enum NotificationPayload {
    static let newTransaction = "/transactions/new"
    static let reconcile = "/reconcile"

    static func budget(month: YearMonth) -> String { "/budget?month=\(month.description)" }
}

/// The screen a tapped notification opens.
enum NotificationRoute: Equatable, Sendable {
    case newTransaction
    case reconcile
    case budget(month: YearMonth?)

    /// Reads a payload back into the screen it opens; nil for an unknown payload.
    static func parse(_ payload: String) -> NotificationRoute? {
        let parts = payload.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        switch parts.first.map(String.init) {
        case "/transactions/new": return .newTransaction
        case "/reconcile": return .reconcile
        case "/budget":
            var month: YearMonth?
            if parts.count == 2 {
                for pair in parts[1].split(separator: "&") {
                    let kv = pair.split(separator: "=", maxSplits: 1)
                    if kv.count == 2, kv[0] == "month" {
                        month = try? YearMonth(parsing: String(kv[1]))
                    }
                }
            }
            return .budget(month: month)
        default: return nil
        }
    }
}
