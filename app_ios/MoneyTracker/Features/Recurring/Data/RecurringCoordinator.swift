import Foundation
import Observation
import UIKit

/// Creates the occurrences that came due (BUSINESS_RULES §5.2) whenever the app is ready, comes
/// back to the foreground, a sync changed the rules, or premium turned on; and announces the ones
/// that wait for confirmation.
@MainActor
final class RecurringCoordinator {
    private static let confirmNotificationID = "mt.recurring.confirm"

    private let generator: RecurringGenerator
    private let database: AppDatabase
    private let gate: AppGateStore
    private let notifications: NotificationService
    private var debounce: Task<Void, Never>?
    private var observation: Task<Void, Never>?
    private var running = false
    private var again = false

    init(
        generator: RecurringGenerator, database: AppDatabase, gate: AppGateStore,
        notifications: NotificationService
    ) {
        self.generator = generator
        self.database = database
        self.gate = gate
        self.notifications = notifications
    }

    func start() {
        guard observation == nil else { return }
        let database = self.database
        // The first value is the run at launch; later ones follow every change of the rules.
        observation = Task { [weak self] in
            while !Task.isCancelled {
                await forEachValue(database.observeRecurringRuleVersions()) { _ in
                    self?.requestRun()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Runs the generator shortly (writes come in bursts).
    func requestRun() {
        debounce?.cancel()
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if Task.isCancelled { return }
            await self?.run()
        }
    }

    private func run() async {
        // Nothing is created while the account is still being set up.
        guard gate.gate == .ready else { return }
        if running {
            again = true
            return
        }
        running = true
        defer {
            running = false
            if again {
                again = false
                requestRun()
            }
        }
        guard let result = try? await generator.run() else { return }
        if result.pendingConfirmation > 0 { await announce(result.pendingConfirmation) }
    }

    private func announce(_ count: Int) async {
        guard await notifications.areEnabled() else { return }
        await notifications.showNow(
            identifier: Self.confirmNotificationID,
            title: String(localized: "Transaksi berulang menunggu konfirmasi"),
            body: String(localized: "Ada \(count) transaksi berulang yang perlu kamu catat atau lewati."),
            payload: NotificationPayload.transactions)
    }
}
