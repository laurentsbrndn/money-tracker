/// Signing in as a different user than the one who owns the local database
/// (SYNC_PROTOCOL §11). The caller must warn the user — [pendingChanges]
/// unsent changes would be lost — and sign in again with local data discarded.
class UserMismatchException implements Exception {
  const UserMismatchException({required this.pendingChanges});

  final int pendingChanges;

  @override
  String toString() => 'UserMismatchException($pendingChanges pending)';
}
