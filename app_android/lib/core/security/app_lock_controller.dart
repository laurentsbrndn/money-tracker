import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import 'app_lock_state.dart';
import 'biometric_service.dart';
import 'lock_storage.dart';
import 'pin_attempt_policy.dart';
import 'pin_hasher.dart';

part 'app_lock_controller.g.dart';

@Riverpod(keepAlive: true)
LockStorage lockStorage(Ref ref) => LockStorage();

@Riverpod(keepAlive: true)
BiometricService biometricService(Ref ref) => BiometricService();

/// Owns the PIN lock (APP_FLOWS Flow 12): the PIN hash and attempts live in
/// secure storage (device only, never synced); the app locks on a cold start
/// and after [AppLockState.autoLockSeconds] in the background.
@Riverpod(keepAlive: true)
class AppLockController extends _$AppLockController {
  Stopwatch? _inBackground;

  LockStorage get _storage => ref.read(lockStorageProvider);

  @override
  AppLockState build() {
    final lifecycle = AppLifecycleListener(
      onPause: _onPause,
      onResume: _onResume,
    );
    ref
      ..onDispose(lifecycle.dispose)
      // The lock belongs to the signed-in user's local data: a signed-out
      // device (logout, deleted account) has no PIN.
      ..listen(sessionControllerProvider, (previous, next) {
        if (next.status == SessionStatus.signedOut &&
            previous?.status != SessionStatus.signedOut) {
          unawaited(clearAll());
        }
      });
    return const AppLockState();
  }

  /// Reads the stored settings. Called from `bootstrap()` so the first frame
  /// is already locked when a PIN is set.
  Future<void> load() async {
    final pin = await _storage.readPin();
    state = AppLockState(
      loaded: true,
      pinSet: pin != null,
      locked: pin != null,
      biometricEnabled: pin != null && await _storage.readBiometric(),
      autoLockSeconds: await _storage.readAutoLockSeconds(),
      failures: await _storage.readFailures(),
      lockedUntil: await _storage.readLockedUntil(),
    );
  }

  void _onPause() {
    if (!state.pinSet || state.locked) {
      return;
    }
    if (state.autoLockSeconds <= 0) {
      state = state.copyWith(locked: true);
      return;
    }
    // A stopwatch is monotonic, so changing the device clock does not extend
    // the unlocked time.
    _inBackground = Stopwatch()..start();
  }

  void _onResume() {
    final watch = _inBackground;
    _inBackground = null;
    if (watch == null || !state.pinSet || state.locked) {
      return;
    }
    if (watch.elapsed.inSeconds >= state.autoLockSeconds) {
      state = state.copyWith(locked: true);
    }
  }

  void lockNow() {
    if (state.pinSet) {
      state = state.copyWith(locked: true);
    }
  }

  /// Checks [pin] against the stored hash, counting wrong tries and imposing
  /// the growing delay of `pin_attempt_policy.dart`.
  Future<PinCheck> check(String pin) async {
    final now = DateTime.now().toUtc();
    if (lockoutSecondsLeft(state.lockedUntil, now) > 0) {
      return PinCheck.lockedOut;
    }
    final stored = await _storage.readPin();
    if (stored == null) {
      return PinCheck.success;
    }
    if (await verifyPin(pin, stored)) {
      await _resetAttempts();
      return PinCheck.success;
    }
    final failures = state.failures + 1;
    final delay = lockoutAfterFailures(failures);
    final lockedUntil = delay == null ? null : DateTime.now().toUtc().add(delay);
    await _storage.writeAttempts(failures: failures, lockedUntil: lockedUntil);
    state = state.copyWith(
      failures: failures,
      lockedUntil: lockedUntil,
      clearLockedUntil: lockedUntil == null,
    );
    return delay == null ? PinCheck.wrong : PinCheck.lockedOut;
  }

  Future<void> _resetAttempts() async {
    await _storage.writeAttempts(failures: 0, lockedUntil: null);
    state = state.copyWith(failures: 0, clearLockedUntil: true);
  }

  /// Unlocks with [pin]; the result tells the lock screen what to show.
  Future<PinCheck> unlock(String pin) async {
    final result = await check(pin);
    if (result == PinCheck.success) {
      state = state.copyWith(locked: false);
    }
    return result;
  }

  /// Unlocks with the fingerprint/face prompt. A successful biometric also
  /// clears the wrong-PIN streak: the device owner proved themselves.
  Future<bool> unlockWithBiometric(String reason) async {
    if (!state.biometricEnabled) {
      return false;
    }
    final ok = await ref.read(biometricServiceProvider).authenticate(reason);
    if (ok) {
      await _resetAttempts();
      state = state.copyWith(locked: false);
    }
    return ok;
  }

  /// Sets the first PIN.
  Future<void> setPin(String pin) async {
    if (!isValidPinFormat(pin)) {
      throw ArgumentError.value(pin, 'pin', 'must be $pinLength digits');
    }
    await _storage.writePin(await createPinHash(pin));
    await _resetAttempts();
    state = state.copyWith(pinSet: true, locked: false);
  }

  /// Turns the lock off after [current] checks out.
  Future<PinCheck> removePin(String current) async {
    final result = await check(current);
    if (result == PinCheck.success) {
      await clearAll();
    }
    return result;
  }

  /// Enables biometrics once the prompt succeeds, so a device without
  /// enrolled biometrics never ends up with a dead setting.
  Future<bool> setBiometric(String reason, {required bool enabled}) async {
    if (!state.pinSet) {
      return false;
    }
    if (enabled && !await ref.read(biometricServiceProvider).authenticate(reason)) {
      return false;
    }
    await _storage.writeBiometric(enabled: enabled);
    state = state.copyWith(biometricEnabled: enabled);
    return true;
  }

  Future<void> setAutoLockSeconds(int seconds) async {
    await _storage.writeAutoLockSeconds(seconds);
    state = state.copyWith(autoLockSeconds: seconds);
  }

  /// Removes the PIN and every lock setting.
  Future<void> clearAll() async {
    await _storage.clear();
    state = const AppLockState(loaded: true);
  }
}
