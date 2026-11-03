import Foundation

/// Device-only lock settings in the Keychain (`WhenUnlockedThisDeviceOnly`). They are never
/// written to the database, so they never sync.
///
/// The Keychain outlives an uninstall while the database does not. A marker in `UserDefaults`
/// is removed with the app; when it is missing this is a fresh install, so every lock item is
/// cleared before any is read, and a reinstall is never locked by an old PIN without its data.
struct LockStorage: Sendable {
    private static let hashKey = "lock_pin_hash"
    private static let saltKey = "lock_pin_salt"
    private static let iterationsKey = "lock_pin_iterations"
    private static let failuresKey = "lock_failures"
    private static let lockedUntilKey = "lock_locked_until"
    private static let biometricKey = "lock_biometric"
    private static let autoLockKey = "lock_auto_seconds"

    private static let installMarker = "moneytracker.lock.installed"
    /// Plain flag: a PIN exists. Lets a launch while the device is locked (the Keychain cannot
    /// be read) still start locked.
    private static let pinFlag = "moneytracker.lock.pin_set"

    /// Lock after 1 minute in the background (APP_FLOWS Flow 12).
    static let defaultAutoLockSeconds = 60

    private let keychain: KeychainStore
    private let defaults: UserDefaultsBox

    /// `UserDefaults` is thread-safe but not `Sendable`.
    private final class UserDefaultsBox: @unchecked Sendable {
        let value: UserDefaults
        init(_ value: UserDefaults) { self.value = value }
    }

    init(keychain: KeychainStore, defaults: UserDefaults = .standard) {
        var store = keychain
        store.accessibility = .whenUnlocked
        self.keychain = store
        self.defaults = UserDefaultsBox(defaults)
        prepareFreshInstall()
    }

    private func prepareFreshInstall() {
        guard !defaults.value.bool(forKey: Self.installMarker) else { return }
        try? keychain.deleteAll()
        defaults.value.removeObject(forKey: Self.pinFlag)
        defaults.value.set(true, forKey: Self.installMarker)
    }

    /// A PIN was set on this device (readable even while the Keychain is not).
    var pinFlagSet: Bool { defaults.value.bool(forKey: Self.pinFlag) }

    private func string(_ key: String) throws -> String? {
        try keychain.read(key).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func write(_ key: String, _ value: String) throws {
        try keychain.write(key, Data(value.utf8))
    }

    /// Throws when the Keychain cannot be read (device locked).
    func readPin() throws -> PinHash? {
        guard let hash = try string(Self.hashKey), let salt = try string(Self.saltKey),
            let iterations = try string(Self.iterationsKey).flatMap(Int.init)
        else { return nil }
        return PinHash(salt: salt, hash: hash, iterations: iterations)
    }

    func writePin(_ pin: PinHash) throws {
        try write(Self.hashKey, pin.hash)
        try write(Self.saltKey, pin.salt)
        try write(Self.iterationsKey, String(pin.iterations))
        defaults.value.set(true, forKey: Self.pinFlag)
    }

    func readFailures() throws -> Int { try string(Self.failuresKey).flatMap(Int.init) ?? 0 }

    func readLockedUntil() throws -> Date? {
        try string(Self.lockedUntilKey).flatMap(Double.init).map {
            Date(timeIntervalSince1970: $0 / 1000)
        }
    }

    func writeAttempts(failures: Int, lockedUntil: Date?) throws {
        if failures == 0 {
            try keychain.delete(Self.failuresKey)
        } else {
            try write(Self.failuresKey, String(failures))
        }
        if let lockedUntil {
            try write(Self.lockedUntilKey, String(Int64(lockedUntil.timeIntervalSince1970 * 1000)))
        } else {
            try keychain.delete(Self.lockedUntilKey)
        }
    }

    func readBiometric() throws -> Bool { try string(Self.biometricKey) == "true" }

    func writeBiometric(enabled: Bool) throws {
        if enabled {
            try write(Self.biometricKey, "true")
        } else {
            try keychain.delete(Self.biometricKey)
        }
    }

    func readAutoLockSeconds() throws -> Int {
        try string(Self.autoLockKey).flatMap(Int.init) ?? Self.defaultAutoLockSeconds
    }

    func writeAutoLockSeconds(_ seconds: Int) throws {
        try write(Self.autoLockKey, String(seconds))
    }

    /// Forgets the PIN and every lock setting (logout, delete account, PIN off).
    func clear() {
        try? keychain.deleteAll()
        defaults.value.removeObject(forKey: Self.pinFlag)
    }
}
