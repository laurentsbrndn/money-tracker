import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';

/// Device-only lock settings in the Android Keystore-backed secure storage.
/// They are never written to the database, so they never sync.
class LockStorage {
  LockStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _hashKey = 'lock_pin_hash';
  static const String _saltKey = 'lock_pin_salt';
  static const String _iterationsKey = 'lock_pin_iterations';
  static const String _failuresKey = 'lock_failures';
  static const String _lockedUntilKey = 'lock_locked_until';
  static const String _biometricKey = 'lock_biometric';
  static const String _autoLockKey = 'lock_auto_seconds';

  /// FRONTEND/APP_FLOWS Flow 12: lock after 1 minute in the background.
  static const int defaultAutoLockSeconds = 60;

  final FlutterSecureStorage _storage;

  Future<PinHash?> readPin() async {
    final hash = await _storage.read(key: _hashKey);
    final salt = await _storage.read(key: _saltKey);
    final iterations = int.tryParse(
      await _storage.read(key: _iterationsKey) ?? '',
    );
    if (hash == null || salt == null || iterations == null) {
      return null;
    }
    return PinHash(salt: salt, hash: hash, iterations: iterations);
  }

  Future<void> writePin(PinHash pin) async {
    await _storage.write(key: _hashKey, value: pin.hash);
    await _storage.write(key: _saltKey, value: pin.salt);
    await _storage.write(key: _iterationsKey, value: '${pin.iterations}');
  }

  Future<int> readFailures() async =>
      int.tryParse(await _storage.read(key: _failuresKey) ?? '') ?? 0;

  Future<DateTime?> readLockedUntil() async {
    final millis = int.tryParse(
      await _storage.read(key: _lockedUntilKey) ?? '',
    );
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  Future<void> writeAttempts({
    required int failures,
    required DateTime? lockedUntil,
  }) async {
    if (failures == 0) {
      await _storage.delete(key: _failuresKey);
    } else {
      await _storage.write(key: _failuresKey, value: '$failures');
    }
    if (lockedUntil == null) {
      await _storage.delete(key: _lockedUntilKey);
    } else {
      await _storage.write(
        key: _lockedUntilKey,
        value: '${lockedUntil.millisecondsSinceEpoch}',
      );
    }
  }

  Future<bool> readBiometric() async =>
      await _storage.read(key: _biometricKey) == 'true';

  Future<void> writeBiometric({required bool enabled}) => enabled
      ? _storage.write(key: _biometricKey, value: 'true')
      : _storage.delete(key: _biometricKey);

  Future<int> readAutoLockSeconds() async =>
      int.tryParse(await _storage.read(key: _autoLockKey) ?? '') ??
      defaultAutoLockSeconds;

  Future<void> writeAutoLockSeconds(int seconds) =>
      _storage.write(key: _autoLockKey, value: '$seconds');

  /// Forget the PIN and every lock setting (logout, delete account, PIN off).
  Future<void> clear() async {
    for (final key in [
      _hashKey,
      _saltKey,
      _iterationsKey,
      _failuresKey,
      _lockedUntilKey,
      _biometricKey,
      _autoLockKey,
    ]) {
      await _storage.delete(key: key);
    }
  }
}
