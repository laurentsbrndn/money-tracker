/// What the list shows for a rule (APP_FLOWS Flow 10).
enum RecurringRuleStatus: Sendable {
    case active
    /// Paused by the user, or by the server for a reason the app does not know.
    case paused
    /// Paused while the server reports no premium: the server pauses every rule when premium ends
    /// (BUSINESS_RULES §7). It can only be resumed with premium.
    case pausedNoPremium
    /// The end date has passed and nothing is left to create.
    case ended
}

extension RecurringRuleRecord {
    /// The pure schedule of `Core/DomainRules`.
    var schedule: RecurrenceRule {
        RecurrenceRule(
            frequency: RecurringFrequency(rawValue: frequency) ?? .daily,
            intervalCount: intervalCount, dayOfWeek: dayOfWeek ?? 0, dayOfMonth: dayOfMonth ?? 0,
            monthOfYear: monthOfYear ?? 0, startDate: startDate, endDate: endDate)
    }

    /// The next date the rule falls on after today, or nil when it has ended.
    func nextDate(today: CivilDate) -> CivilDate? {
        // A date that was already created is not "next" any more.
        var after = today.adding(days: -1)
        if let last = lastGeneratedDate, last > after { after = last }
        return DomainRules.nextOccurrence(rule: schedule, after: after)
    }

    func status(today: CivilDate, premium: Bool) -> RecurringRuleStatus {
        if isPaused { return premium ? .paused : .pausedNoPremium }
        return nextDate(today: today) == nil ? .ended : .active
    }
}
