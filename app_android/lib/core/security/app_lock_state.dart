/// The state of the app lock (APP_FLOWS Flow 12 "Keamanan").
class AppLockState {
  const AppLockState({
    this.loaded = false,
    this.pinSet = false,
    this.locked = false,
    this.biometricEnabled = false,
    this.autoLockSeconds = 60,
    this.failures = 0,
    this.lockedUntil,
  });

  /// Whether the stored settings were read yet.
  final bool loaded;

  /// A PIN is set, so the app can be locked.
  final bool pinSet;

  /// The lock screen covers the app.
  final bool locked;
  final bool biometricEnabled;

  /// Time in the background before the app locks; 0 locks right away.
  final int autoLockSeconds;

  /// Consecutive wrong PINs.
  final int failures;

  /// The PIN pad is blocked until then (UTC).
  final DateTime? lockedUntil;

  AppLockState copyWith({
    bool? loaded,
    bool? pinSet,
    bool? locked,
    bool? biometricEnabled,
    int? autoLockSeconds,
    int? failures,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) => AppLockState(
    loaded: loaded ?? this.loaded,
    pinSet: pinSet ?? this.pinSet,
    locked: locked ?? this.locked,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    autoLockSeconds: autoLockSeconds ?? this.autoLockSeconds,
    failures: failures ?? this.failures,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );
}

/// Outcome of checking a PIN.
enum PinCheck { success, wrong, lockedOut }
