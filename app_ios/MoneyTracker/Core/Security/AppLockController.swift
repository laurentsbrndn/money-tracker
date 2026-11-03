import Foundation
import Observation
import SwiftUI

/// Outcome of checking a PIN.
enum PinCheck: Sendable, Equatable {
    case success
    case wrong
    case lockedOut
}

/// Owns the PIN lock (APP_FLOWS Flow 12): the PIN hash and the attempts live in the Keychain
/// (device only, never synced). The app locks on a cold start and after `autoLockSeconds` in the
/// background, measured with a monotonic clock so changing the device clock does not extend the
/// unlocked time. The lock is drawn by `ScreenShield` above everything, sheets included.
@Observable
@MainActor
final class AppLockController {
    /// Whether the stored settings were read.
    private(set) var loaded = false
    /// A PIN is set, so the app can be locked.
    private(set) var pinSet = false
    /// The lock screen covers the app. Starts true when a PIN was set on this device, so the first
    /// frame is already covered.
    private(set) var locked: Bool
    private(set) var biometricEnabled = false
    /// Time in the background before the app locks; 0 locks right away.
    private(set) var autoLockSeconds = LockStorage.defaultAutoLockSeconds
    /// Consecutive wrong PINs.
    private(set) var failures = 0
    /// The PIN pad is blocked until then.
    private(set) var lockedUntil: Date?
    /// Bumped whenever the lock screen should offer the biometric prompt on its own.
    private(set) var promptToken = 0

    let biometric: BiometricService

    private let storage: LockStorage
    private var backgroundedAt: ContinuousClock.Instant?
    private var checking = false
    /// The lock engaged since the biometric prompt was last offered.
    private var promptPending = false

    init(storage: LockStorage, biometric: BiometricService = BiometricService()) {
        self.storage = storage
        self.biometric = biometric
        self.locked = storage.pinFlagSet
        self.promptPending = locked
    }

    /// Covers the app and offers the biometric prompt once when it becomes active.
    private func engageLock() {
        locked = true
        promptPending = true
    }

    /// Reads the stored settings. While the device is locked the Keychain cannot be read (iOS
    /// launched the app in the background); the app then stays locked if a PIN was set and tries
    /// again when it becomes active.
    func load() {
        do {
            let pin = try storage.readPin()
            pinSet = pin != nil
            let shouldLock = pin != nil && (locked || !loaded)
            if shouldLock && !locked { engageLock() }
            locked = shouldLock
            let biometric = try storage.readBiometric()
            biometricEnabled = pin != nil && biometric
            autoLockSeconds = try storage.readAutoLockSeconds()
            failures = try storage.readFailures()
            lockedUntil = try storage.readLockedUntil()
            loaded = true
        } catch {
            if !locked && storage.pinFlagSet { engageLock() }
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            guard pinSet, !locked else { return }
            if autoLockSeconds <= 0 {
                engageLock()
            } else {
                backgroundedAt = .now
            }
        case .active:
            if !loaded { load() }
            defer {
                if locked && biometricEnabled && promptPending {
                    promptPending = false
                    promptToken += 1
                }
            }
            guard let since = backgroundedAt else { return }
            backgroundedAt = nil
            guard pinSet, !locked else { return }
            let elapsed = ContinuousClock.now - since
            if elapsed >= .seconds(autoLockSeconds) { engageLock() }
        default:
            break
        }
    }

    func lockNow() {
        if pinSet { engageLock() }
    }

    /// Checks `pin` against the stored hash, counting wrong tries and imposing the growing delay
    /// of `PinAttemptPolicy`.
    func check(_ pin: String) async -> PinCheck {
        guard !checking else { return .wrong }
        checking = true
        defer { checking = false }
        if PinAttemptPolicy.secondsLeft(until: lockedUntil, now: Date()) > 0 { return .lockedOut }
        guard let stored = try? storage.readPin() else { return .success }
        if await PinHasher.verify(pin, against: stored) {
            resetAttempts()
            return .success
        }
        failures += 1
        let delay = PinAttemptPolicy.lockout(afterFailures: failures)
        lockedUntil = delay.map { Date().addingTimeInterval($0) }
        try? storage.writeAttempts(failures: failures, lockedUntil: lockedUntil)
        return delay == nil ? .wrong : .lockedOut
    }

    private func resetAttempts() {
        failures = 0
        lockedUntil = nil
        try? storage.writeAttempts(failures: 0, lockedUntil: nil)
    }

    /// Unlocks with `pin`; the result tells the lock screen what to show.
    func unlock(_ pin: String) async -> PinCheck {
        let result = await check(pin)
        if result == .success { locked = false }
        return result
    }

    /// Unlocks with Face ID / Touch ID. A successful biometric also clears the wrong-PIN streak:
    /// the device owner proved themselves.
    func unlockWithBiometric(reason: String) async -> Bool {
        guard biometricEnabled, locked else { return false }
        guard await biometric.authenticate(reason: reason) else { return false }
        resetAttempts()
        locked = false
        return true
    }

    /// Sets the first PIN (or replaces it).
    func setPin(_ pin: String) async throws {
        guard PinHasher.isValidFormat(pin) else { throw PinError.format }
        let hash = try await PinHasher.create(pin)
        try storage.writePin(hash)
        resetAttempts()
        pinSet = true
        loaded = true
        locked = false
    }

    /// Turns the lock off after `current` checks out.
    func removePin(current: String) async -> PinCheck {
        let result = await check(current)
        if result == .success { clearAll() }
        return result
    }

    /// Enables biometrics once the prompt succeeds, so a device without enrolled biometrics never
    /// ends up with a dead setting.
    func setBiometric(enabled: Bool, reason: String) async -> Bool {
        guard pinSet else { return false }
        if enabled, !(await biometric.authenticate(reason: reason)) { return false }
        do { try storage.writeBiometric(enabled: enabled) } catch { return false }
        biometricEnabled = enabled
        return true
    }

    func setAutoLockSeconds(_ seconds: Int) {
        try? storage.writeAutoLockSeconds(seconds)
        autoLockSeconds = seconds
    }

    /// Removes the PIN and every lock setting (logout, delete account, PIN off).
    func clearAll() {
        storage.clear()
        pinSet = false
        locked = false
        biometricEnabled = false
        autoLockSeconds = LockStorage.defaultAutoLockSeconds
        failures = 0
        lockedUntil = nil
        loaded = true
        backgroundedAt = nil
    }

    enum PinError: Error { case format }
}
