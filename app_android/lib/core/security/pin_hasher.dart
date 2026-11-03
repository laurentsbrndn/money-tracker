import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'sha256.dart';

/// A salted, stretched PIN hash. The raw PIN is never stored.
class PinHash {
  const PinHash({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Base64 of 16 random bytes.
  final String salt;

  /// Base64 of the PBKDF2-HMAC-SHA256 output.
  final String hash;
  final int iterations;
}

/// PBKDF2 rounds used for new hashes; kept with each hash so it can be raised
/// later without invalidating existing PINs.
const int pinHashIterations = 30000;

/// Number of digits of a PIN (APP_FLOWS Flow 12).
const int pinLength = 6;

bool isValidPinFormat(String pin) => RegExp('^\\d{$pinLength}\$').hasMatch(pin);

/// Hashes [pin] with a fresh random salt, off the UI isolate.
Future<PinHash> createPinHash(String pin, {Random? random}) {
  final rng = random ?? Random.secure();
  final salt = Uint8List.fromList([for (var i = 0; i < 16; i++) rng.nextInt(256)]);
  return Isolate.run(
    () => PinHash(
      salt: base64Encode(salt),
      hash: base64Encode(_derive(pin, salt, pinHashIterations)),
      iterations: pinHashIterations,
    ),
  );
}

/// Whether [pin] matches [stored], off the UI isolate.
Future<bool> verifyPin(String pin, PinHash stored) {
  final salt = base64Decode(stored.salt);
  final expected = base64Decode(stored.hash);
  final iterations = stored.iterations;
  return Isolate.run(
    () => constantTimeEquals(_derive(pin, salt, iterations), expected),
  );
}

Uint8List _derive(String pin, List<int> salt, int iterations) =>
    pbkdf2HmacSha256(
      password: utf8.encode(pin),
      salt: salt,
      iterations: iterations,
    );

/// Compares without returning early on the first differing byte.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) {
    return false;
  }
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
