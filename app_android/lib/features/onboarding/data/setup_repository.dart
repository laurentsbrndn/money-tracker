import '../../../core/auth/session_controller.dart';
import '../../../core/database/app_database.dart';

/// Flags of the one-time setup wizard (APP_FLOWS Flow 1, step 6). The data the
/// wizard edits goes through the accounts and categories repositories.
class SetupRepository {
  const SetupRepository(this._db);

  final AppDatabase _db;

  /// The Cash account created by the server's onboarding seed.
  Future<AccountRow?> findCash() async {
    final accounts = await _db.accountsDao.allActive();
    for (final account in accounts) {
      if (account.type == 'cash') {
        return account;
      }
    }
    return null;
  }

  /// Wizard finished or skipped: it is never shown again for this user.
  Future<void> markDone() => _db.syncStateDao.write(setupPendingKey, 'false');
}
