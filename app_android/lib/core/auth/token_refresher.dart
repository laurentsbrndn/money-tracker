import '../network/api_exception.dart';
import 'auth_tokens.dart';
import 'token_storage.dart';

const Duration _refreshMargin = Duration(seconds: 60);

/// Hands out a valid access token and refreshes it **single-flight**: while one
/// refresh runs, every other caller waits for that same result, so the
/// rotating refresh token is never spent twice (API reuse detection).
class TokenRefresher {
  TokenRefresher({
    required this._storage,
    required this._requestRefresh,
    required this._onSessionExpired,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TokenStorage _storage;
  final Future<AuthTokens> Function(String refreshToken) _requestRefresh;
  final Future<void> Function() _onSessionExpired;
  final DateTime Function() _now;

  AuthTokens? _cached;
  Future<AuthTokens?>? _inFlight;

  /// A token usable now, refreshing first when it expires within 60 seconds.
  /// Null when there is no session or the session could not be renewed.
  /// Network failures during a refresh are rethrown.
  Future<String?> validAccessToken() async {
    final tokens = _cached ??= await _storage.readTokens();
    if (tokens == null) {
      return null;
    }
    if (!tokens.accessExpiresWithin(_refreshMargin, _now())) {
      return tokens.accessToken;
    }
    return (await _refresh())?.accessToken;
  }

  /// Called after the server rejected [rejectedToken] as expired. If another
  /// request already renewed the token, that one is returned without a second
  /// refresh.
  Future<String?> renewAfterRejection(String rejectedToken) async {
    final current = _cached ?? await _storage.readTokens();
    if (current != null &&
        current.accessToken != rejectedToken &&
        !current.accessExpiresWithin(_refreshMargin, _now())) {
      _cached = current;
      return current.accessToken;
    }
    return (await _refresh())?.accessToken;
  }

  /// Store the tokens of a fresh login.
  Future<void> setTokens(AuthTokens tokens) async {
    await _storage.writeTokens(tokens);
    _cached = tokens;
  }

  /// Drop the in-memory copy; the next call reads storage again (the
  /// background isolate may have rotated the tokens meanwhile).
  void reload() => _cached = null;

  void clear() {
    _cached = null;
    _inFlight = null;
  }

  Future<AuthTokens?> _refresh() =>
      _inFlight ??= _doRefresh().whenComplete(() => _inFlight = null);

  Future<AuthTokens?> _doRefresh() async {
    // Always take the refresh token from storage: another isolate may have
    // rotated it since this one cached anything.
    final stored = await _storage.readTokens();
    if (stored == null || stored.refreshExpired(_now())) {
      await _expire();
      return null;
    }
    try {
      final renewed = await _requestRefresh(stored.refreshToken);
      await _storage.writeTokens(renewed);
      _cached = renewed;
      return renewed;
    } on Object catch (error) {
      final problem = ApiException.from(error);
      if (problem != null && problem.status == 401) {
        await _expire();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _expire() async {
    _cached = null;
    await _onSessionExpired();
  }
}
