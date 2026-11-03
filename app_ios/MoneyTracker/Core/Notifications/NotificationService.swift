import Foundation
import Synchronization
import UIKit
import UserNotifications

/// Thin wrapper over `UNUserNotificationCenter`: permission, scheduling, immediate banners, and
/// the delegate that shows banners in the foreground and reports taps. Framework only, no
/// library (FRONTEND_IOS §1).
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, Sendable {
    /// `userInfo` key that carries the route payload.
    private static let routeKey = "route"

    /// The system center is thread-safe; read on use so the class itself stays `Sendable`.
    private var center: UNUserNotificationCenter { .current() }
    private let tapHandler = Mutex<(@MainActor @Sendable (String) -> Void)?>(nil)

    /// Must be called before the app finishes launching, so a notification that cold-starts the
    /// app is delivered to `onTap`.
    func install(onTap: @escaping @MainActor @Sendable (String) -> Void) {
        tapHandler.withLock { $0 = onTap }
        center.delegate = self
    }

    // MARK: - Permission

    /// Whether the system allows this app to show notifications.
    func areEnabled() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    /// Whether the permission was never asked (the system dialog can still appear).
    func isUndetermined() async -> Bool {
        await center.notificationSettings().authorizationStatus == .notDetermined
    }

    /// Asks for the permission; returns whether it is granted.
    @discardableResult
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Scheduling

    /// Removes every pending notification this app scheduled from the plan (identifiers with the
    /// plan prefix), so scheduling again is idempotent.
    func cancelPlanned() async {
        let ids = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix(NotificationPlan.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Removes the plan and every delivered budget banner (sign-out).
    func cancelAll() async {
        await cancelPlanned()
        center.removeAllDeliveredNotifications()
    }

    /// Schedules `planned` for its moment in `userZone`. The trigger uses the calendar components
    /// of that instant in the device's current timezone (`TimeZone.current`).
    func schedule(
        _ planned: PlannedNotification, userZone: TimeZone, title: String, body: String
    ) async {
        guard let instant = NotificationFireTime.fireDate(for: planned, userZone: userZone)
        else { return }
        let components = NotificationFireTime.deviceComponents(
            for: instant, deviceZone: TimeZone.current)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationPlan.identifier(for: planned.id),
            content: content(title: title, body: body, payload: planned.payload),
            trigger: trigger)
        try? await center.add(request)
    }

    /// Delivers a notification right away.
    func showNow(identifier: String, title: String, body: String, payload: String) async {
        let request = UNNotificationRequest(
            identifier: identifier, content: content(title: title, body: body, payload: payload),
            trigger: nil)
        try? await center.add(request)
    }

    private func content(title: String, body: String, payload: String)
        -> UNMutableNotificationContent
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [Self.routeKey: payload]
        return content
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// In the foreground a notification still shows as a banner.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
            let payload = response.notification.request.content.userInfo[Self.routeKey] as? String
        else { return }
        let handler = tapHandler.withLock { $0 }
        await handler?(payload)
    }
}
