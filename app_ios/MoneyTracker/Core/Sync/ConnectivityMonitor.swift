import Network
import Synchronization

/// Reachability from `NWPathMonitor` (SYNC_PROTOCOL §7 triggers). Until the first path update
/// arrives the device counts as online, so the first sync is not held back.
final class ConnectivityMonitor: Sendable {
    private let monitor = NWPathMonitor()
    private let online = Mutex(true)
    private let listeners = Mutex<[UInt64: AsyncStream<Bool>.Continuation]>([:])
    private let nextID = Mutex<UInt64>(0)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.update(path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "moneytracker.connectivity"))
    }

    deinit {
        monitor.cancel()
    }

    var isOnline: Bool { online.withLock { $0 } }

    /// Emits the current state, then every change.
    func changes() -> AsyncStream<Bool> {
        let id = nextID.withLock { value -> UInt64 in
            value += 1
            return value
        }
        return AsyncStream { continuation in
            continuation.yield(isOnline)
            listeners.withLock { $0[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.listeners.withLock { _ = $0.removeValue(forKey: id) }
            }
        }
    }

    private func update(_ value: Bool) {
        let changed = online.withLock { current -> Bool in
            defer { current = value }
            return current != value
        }
        guard changed else { return }
        for continuation in listeners.withLock({ Array($0.values) }) {
            continuation.yield(value)
        }
    }
}
