import LocalAuthentication

/// Face ID / Touch ID through `LocalAuthentication`. A failed or cancelled prompt just returns
/// false; the lock screen always offers the PIN as the fallback.
struct BiometricService: Sendable {
    /// Whether the device has an enrolled biometric.
    func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// "Face ID" or "Touch ID" (or a neutral word when there is none).
    func kindName() -> String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return String(localized: "biometrik")
        }
    }

    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        // Empty fallback title hides the system "Enter Password" button: the PIN pad is the
        // fallback, not the device passcode.
        context.localizedFallbackTitle = ""
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}
