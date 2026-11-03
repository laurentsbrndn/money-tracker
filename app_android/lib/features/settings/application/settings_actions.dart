import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/network/api_client_provider.dart';
import '../data/settings_repository.dart';

part 'settings_actions.g.dart';

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
SettingsActions settingsActions(Ref ref) => SettingsActions(ref);

/// Account use cases of the settings screens. Errors are thrown for the
/// screen to show with `describeError`.
class SettingsActions {
  SettingsActions(this._ref);

  final Ref _ref;

  SettingsRepository get _repository => _ref.read(settingsRepositoryProvider);

  SessionController get _session =>
      _ref.read(sessionControllerProvider.notifier);

  Future<void> updateName(String name) async {
    final user = await _repository.updateName(name.trim());
    await _session.updateUser(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _repository.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  /// Unsent changes that logging out would lose.
  Future<int> pendingChanges() =>
      _ref.read(appDatabaseProvider).outboxDao.countAll();

  Future<void> logout() => _session.logout();

  /// Deletes the account on the server, then all local data.
  Future<void> deleteAccount(String confirmation) async {
    await _repository.deleteAccount(confirmation);
    await _session.clearLocalSession();
  }
}
