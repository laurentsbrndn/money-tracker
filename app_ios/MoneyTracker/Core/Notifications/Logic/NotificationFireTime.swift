import Foundation

/// Turns a planned wall-clock moment in the user's timezone into the calendar components a
/// `UNCalendarNotificationTrigger` needs. The trigger fires when the device's own clock reads the
/// components, so the user's moment is first made an absolute `Date` and then read back in the
/// device's timezone; nothing relies on `DateComponents.timeZone`.
enum NotificationFireTime {
    /// The absolute instant of `planned` in `userZone`; nil if the date cannot be built.
    static func fireDate(for planned: PlannedNotification, userZone: TimeZone) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = userZone
        return calendar.date(
            from: DateComponents(
                year: planned.date.year, month: planned.date.month, day: planned.date.day,
                hour: planned.hour, minute: planned.minute))
    }

    /// The components of `instant` on the device's calendar and timezone, for a non-repeating
    /// trigger.
    static func deviceComponents(for instant: Date, deviceZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = deviceZone
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
    }
}
