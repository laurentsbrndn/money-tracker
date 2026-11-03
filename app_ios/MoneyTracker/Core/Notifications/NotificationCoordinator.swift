import Foundation
import Observation
import UIKit

/// Keeps the local notifications in step with the app (FRONTEND_IOS §4.5): they are rebuilt when
/// the app opens, becomes active, and whenever settings, transactions, snapshots, accounts, or
/// goals change, which includes changes a sync just pulled. The background refresh calls
/// `refreshNow()` at its end. It also hands a tapped notification to the router.
@Observable
@MainActor
final class NotificationCoordinator {
    let service: NotificationService
    let scheduler: NotificationScheduler

    private let database: AppDatabase
    private var observation: Task<Void, Never>?
    private var debounce: Task<Void, Never>?
    private var clockObservers: [Task<Void, Never>] = []

    init(database: AppDatabase, service: NotificationService, scheduler: NotificationScheduler) {
        self.database = database
        self.service = service
        self.scheduler = scheduler
    }

    /// Starts watching the data. The first value arrives right away, which is the refresh at
    /// app launch. An observation that ends (the database was wiped on logout) restarts.
    func start() {
        guard observation == nil else { return }
        startWatchingClock()
        let database = self.database
        observation = Task { [weak self] in
            while !Task.isCancelled {
                await forEachValue(database.observeNotificationInputs()) { _ in
                    self?.requestRefresh()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// The triggers are device-local components, so a changed device timezone, or a clock jump
    /// (including a daylight saving change), makes the schedule stale: rebuild it.
    func startWatchingClock() {
        guard clockObservers.isEmpty else { return }
        let names: [Notification.Name] = [
            .NSSystemTimeZoneDidChange, UIApplication.significantTimeChangeNotification,
        ]
        clockObservers = names.map { name in
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    self?.requestRefresh()
                }
            }
        }
    }

    /// Rebuilds the schedule shortly (writes often come in bursts).
    func requestRefresh() {
        debounce?.cancel()
        debounce = Task { [scheduler] in
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            await scheduler.refresh()
        }
    }

    /// Rebuilds the schedule now and waits for it (end of a background refresh).
    func refreshNow() async {
        debounce?.cancel()
        await scheduler.refresh()
    }

    /// Sign-out: nothing of this user may remain scheduled.
    func cancelAll() async {
        debounce?.cancel()
        await scheduler.cancelAll()
    }
}
