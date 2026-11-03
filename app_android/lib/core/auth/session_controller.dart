import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database_provider.dart';
import '../network/api_client_provider.dart';
import '../network/generated/models/auth_response.dart';
import '../network/generated/models/refresh_request.dart';
import 'auth_tokens.dart';
import 'session_state.dart';
import 'session_user.dart';
import 'user_mismatch_exception.dart';

part 'session_controller.g.dart';

const String userIdKey = 'user_id';
const String initialSyncDoneKey = 'initial_sync_done';
const String setupPendingKey = 'setup_pending';

/// Owns who is signed in (FRONTEND_FLUTTER §4.2). Tokens live in secure
/// storage; the user id of the local database in `sync_state`.
@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  @override
  SessionState build() => const SessionState.loading();

  /// Reads the stored session. Called once from `bootstrap()`.
  Future<void> load() async {
    final storage = ref.read(tokenStorageProvider);
    final tokens = await storage.readTokens();
    final user = await storage.readUser();
    if (tokens == null || user == null) {
      state = const SessionState.signedOut();
      return;
    }
    final needsLogin = await storage.readNeedsLogin();
    state = SessionState(
      needsLogin ? SessionStatus.needsLogin : SessionStatus.authenticated,
      user,
    );
  }

  /// Starts a session from a login/register response. Throws
  /// [UserMismatchException] if the local database belongs to another user
  /// and [discardLocalData] is false.
  Future<void> establish(
    AuthResponse response, {
    bool discardLocalData = false,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final owner = await db.syncStateDao.read(userIdKey);
    if (owner != null && owner != response.user.id) {
      if (!discardLocalData) {
        throw UserMismatchException(
          pendingChanges: await db.outboxDao.countAll(),
        );
      }
      await _wipeLocalData();
    }
    final database = ref.read(appDatabaseProvider);
    final storage = ref.read(tokenStorageProvider);
    final tokens = AuthTokens(
      accessToken: response.tokens.accessToken,
      accessExpiresAt: response.tokens.accessExpiresAt,
      refreshToken: response.tokens.refreshToken,
      refreshExpiresAt: response.tokens.refreshExpiresAt,
    );
    final user = SessionUser.fromApi(response.user);
    await ref.read(tokenRefresherProvider).setTokens(tokens);
    await storage.writeUser(user);
    await storage.writeNeedsLogin(false);
    await database.syncStateDao.write(userIdKey, user.id);
    if (response.isNewUser) {
      await database.syncStateDao.write(setupPendingKey, 'true');
    }
    state = SessionState(SessionStatus.authenticated, user);
  }

  /// Replaces the stored user after a profile or verification change.
  Future<void> updateUser(SessionUser user) async {
    await ref.read(tokenStorageProvider).writeUser(user);
    state = SessionState(state.status, user);
  }

  /// Refreshing failed for good (SYNC_PROTOCOL §11). Data and outbox stay.
  Future<void> markNeedsLogin() async {
    if (state.status != SessionStatus.authenticated) {
      return;
    }
    await ref.read(tokenStorageProvider).writeNeedsLogin(true);
    state = SessionState(SessionStatus.needsLogin, state.user);
  }

  /// Revokes the refresh token (best effort) and deletes all local data.
  Future<void> logout() async {
    final tokens = await ref.read(tokenStorageProvider).readTokens();
    if (tokens != null) {
      try {
        await ref
            .read(apiClientProvider)
            .auth
            .logout(body: RefreshRequest(refreshToken: tokens.refreshToken));
      } on Object {
        // Offline or already revoked: the local session ends either way.
      }
    }
    await clearLocalSession();
  }

  /// Ends the session and deletes the local database without calling the API
  /// (after account deletion, or when logout has already been requested).
  Future<void> clearLocalSession() async {
    await ref.read(tokenStorageProvider).clear();
    ref.read(tokenRefresherProvider).clear();
    state = const SessionState.signedOut();
    await _wipeLocalData();
  }

  Future<void> _wipeLocalData() async {
    // Let the screens that watch the database leave the tree first.
    await WidgetsBinding.instance.endOfFrame;
    await ref.read(appDatabaseProvider.notifier).wipeAndReopen();
  }
}
