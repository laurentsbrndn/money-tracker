import 'dart:typed_data';

/// SHA-256, HMAC-SHA256, and PBKDF2-HMAC-SHA256 in pure Dart.
///
/// The PIN hash needs a key-stretching function and the project allows no
/// package for it (CLAUDE.md: new libraries need approval), so the three
/// primitives are implemented here per FIPS 180-4, RFC 2104, and RFC 8018.
/// They are only used for the device-local PIN check, never for network data.

const List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

const int _mask = 0xffffffff;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

/// SHA-256 digest (32 bytes) of [message].
Uint8List sha256(List<int> message) {
  final h = Uint32List.fromList([
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ]);

  final bitLength = message.length * 8;
  final padded = _ByteBuffer(message.length + 72)
    ..addAll(message)
    ..add(0x80);
  while ((padded.length % 64) != 56) {
    padded.add(0);
  }
  for (var shift = 56; shift >= 0; shift -= 8) {
    padded.add((bitLength >> shift) & 0xff);
  }
  final data = padded.bytes;

  final w = Uint32List(64);
  for (var offset = 0; offset < data.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final j = offset + i * 4;
      w[i] =
          (data[j] << 24) |
          (data[j + 1] << 16) |
          (data[j + 2] << 8) |
          data[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask;
    }
    var a = h[0];
    var b = h[1];
    var c = h[2];
    var d = h[3];
    var e = h[4];
    var f = h[5];
    var g = h[6];
    var hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _mask) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }
    h[0] = (h[0] + a) & _mask;
    h[1] = (h[1] + b) & _mask;
    h[2] = (h[2] + c) & _mask;
    h[3] = (h[3] + d) & _mask;
    h[4] = (h[4] + e) & _mask;
    h[5] = (h[5] + f) & _mask;
    h[6] = (h[6] + g) & _mask;
    h[7] = (h[7] + hh) & _mask;
  }

  final out = Uint8List(32);
  for (var i = 0; i < 8; i++) {
    out[i * 4] = (h[i] >> 24) & 0xff;
    out[i * 4 + 1] = (h[i] >> 16) & 0xff;
    out[i * 4 + 2] = (h[i] >> 8) & 0xff;
    out[i * 4 + 3] = h[i] & 0xff;
  }
  return out;
}

/// Growable byte buffer.
class _ByteBuffer {
  _ByteBuffer(int capacity) : _data = Uint8List(capacity < 64 ? 64 : capacity);

  Uint8List _data;
  int length = 0;

  void add(int byte) {
    _ensure(1);
    _data[length++] = byte;
  }

  void addAll(List<int> bytes) {
    _ensure(bytes.length);
    _data.setRange(length, length + bytes.length, bytes);
    length += bytes.length;
  }

  void _ensure(int extra) {
    if (length + extra <= _data.length) {
      return;
    }
    final grown = Uint8List((length + extra) * 2)..setRange(0, length, _data);
    _data = grown;
  }

  Uint8List get bytes => Uint8List.sublistView(_data, 0, length);
}

/// HMAC-SHA256 (RFC 2104) of [message] under [key].
Uint8List hmacSha256(List<int> key, List<int> message) {
  final block = Uint8List(64);
  if (key.length > 64) {
    block.setRange(0, 32, sha256(key));
  } else {
    block.setRange(0, key.length, key);
  }
  final inner = Uint8List(64 + message.length);
  final outer = Uint8List(64 + 32);
  for (var i = 0; i < 64; i++) {
    inner[i] = block[i] ^ 0x36;
    outer[i] = block[i] ^ 0x5c;
  }
  inner.setRange(64, 64 + message.length, message);
  outer.setRange(64, 96, sha256(inner));
  return sha256(outer);
}

/// PBKDF2-HMAC-SHA256 (RFC 8018) deriving [length] bytes.
Uint8List pbkdf2HmacSha256({
  required List<int> password,
  required List<int> salt,
  required int iterations,
  int length = 32,
}) {
  final blocks = (length + 31) ~/ 32;
  final out = Uint8List(blocks * 32);
  for (var block = 1; block <= blocks; block++) {
    final input = Uint8List(salt.length + 4)
      ..setRange(0, salt.length, salt)
      ..[salt.length] = (block >> 24) & 0xff
      ..[salt.length + 1] = (block >> 16) & 0xff
      ..[salt.length + 2] = (block >> 8) & 0xff
      ..[salt.length + 3] = block & 0xff;
    var u = hmacSha256(password, input);
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmacSha256(password, u);
      for (var j = 0; j < 32; j++) {
        t[j] ^= u[j];
      }
    }
    out.setRange((block - 1) * 32, block * 32, t);
  }
  return Uint8List.sublistView(out, 0, length);
}
