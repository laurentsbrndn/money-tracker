import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_tokens.dart';
import 'session_user.dart';

/// Tokens and the signed-in user, kept in the Android Keystore-backed secure
/// storage (FRONTEND_FLUTTER §4.2). Every read goes to storage, so the main
/// isolate and the background sync isolate always see the same, latest
/// (rotated) refresh token.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _tokensKey = 'auth_tokens';
  static const String _userKey = 'auth_user';
  static const String _needsLoginKey = 'auth_needs_login';

  final FlutterSecureStorage _storage;

  Future<AuthTokens?> readTokens() async {
    final raw = await _storage.read(key: _tokensKey);
    if (raw == null) {
      return null;
    }
    try {
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> writeTokens(AuthTokens tokens) =>
      _storage.write(key: _tokensKey, value: jsonEncode(tokens.toJson()));

  Future<SessionUser?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) {
      return null;
    }
    try {
      return SessionUser.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  Future<void> writeUser(SessionUser user) =>
      _storage.write(key: _userKey, value: jsonEncode(user.toJson()));

  /// Set when refreshing failed for good (SYNC_PROTOCOL §11); local data stays.
  Future<bool> readNeedsLogin() async =>
      await _storage.read(key: _needsLoginKey) == 'true';

  Future<void> writeNeedsLogin(bool value) => value
      ? _storage.write(key: _needsLoginKey, value: 'true')
      : _storage.delete(key: _needsLoginKey);

  /// Forget the whole session (logout / delete account).
  Future<void> clear() async {
    await _storage.delete(key: _tokensKey);
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _needsLoginKey);
  }
}
