import 'session_user.dart';

enum SessionStatus {
  /// Storage has not been read yet.
  loading,
  signedOut,
  authenticated,

  /// Refreshing the token failed for good; data and outbox are kept
  /// (SYNC_PROTOCOL §11) and the user is asked to sign in again.
  needsLogin,
}

class SessionState {
  const SessionState(this.status, [this.user]);

  const SessionState.loading() : this(SessionStatus.loading);

  const SessionState.signedOut() : this(SessionStatus.signedOut);

  final SessionStatus status;
  final SessionUser? user;

  bool get hasSession =>
      status == SessionStatus.authenticated ||
      status == SessionStatus.needsLogin;
}
