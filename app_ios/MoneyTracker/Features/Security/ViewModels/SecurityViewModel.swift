import Observation

/// Lainnya → Keamanan (APP_FLOWS Flow 12): app lock, biometrics, auto-lock, hide amounts. PIN,
/// biometrics, and auto-lock are device-only (Keychain); "sembunyikan nominal" syncs.
@Observable
@MainActor
final class SecurityViewModel {
    var errorMessage: String?

    private let lock: AppLockController
    private let repository: UserSettingsRepository

    init(container: AppContainer) {
        lock = container.lock
        repository = container.userSettings
    }

    var biometricAvailable: Bool { lock.biometric.isAvailable() }
    var biometricName: String { lock.biometric.kindName() }

    func setBiometric(_ enabled: Bool) async {
        let ok = await lock.setBiometric(
            enabled: enabled, reason: String(localized: "Aktifkan buka kunci dengan biometrik"))
        if !ok && enabled { errorMessage = String(localized: "Biometrik tidak bisa diaktifkan.") }
    }

    func setAutoLock(_ seconds: Int) { lock.setAutoLockSeconds(seconds) }

    func setHideAmounts(_ hide: Bool) async {
        do { try await repository.setHideAmounts(hide) } catch {
            errorMessage = ErrorMessages.describe(error)
        }
    }
}
