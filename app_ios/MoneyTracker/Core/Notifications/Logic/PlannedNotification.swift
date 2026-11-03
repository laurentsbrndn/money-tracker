enum NotificationKind: String, Sendable {
    case daily
    case reconcileMonthEnd
    case reconcileStale
    case monthEvaluation
}

/// One scheduled notification, as a wall-clock moment in the user's timezone. The text is added
/// when it is scheduled, so this stays pure.
struct PlannedNotification: Sendable, Equatable {
    var id: Int
    var kind: NotificationKind
    var date: CivilDate
    var hour: Int
    var minute: Int
    /// App route opened when the notification is tapped (see `NotificationRoute`).
    var payload: String

    var minutesOfDay: Int { hour * 60 + minute }
}
