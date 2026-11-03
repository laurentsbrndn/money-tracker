import '../../../core/auth/session_user.dart';
import '../../../core/network/generated/models/change_password_request.dart';
import '../../../core/network/generated/models/delete_me_request.dart';
import '../../../core/network/generated/models/update_me_request.dart';
import '../../../core/network/generated/money_tracker_api.dart';

/// Online-only account calls of the settings screens (ARCHITECTURE §4).
class SettingsRepository {
  const SettingsRepository(this._api);

  final MoneyTrackerApi _api;

  Future<SessionUser> updateName(String name) async {
    final envelope = await _api.me.updateMe(body: UpdateMeRequest(name: name));
    return SessionUser.fromApi(envelope.user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _api.auth.changePassword(
    body: ChangePasswordRequest(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  /// `DELETE /v1/me`; [confirmation] is the password (users with a password)
  /// or the word `HAPUS`.
  Future<void> deleteAccount(String confirmation) =>
      _api.me.deleteMe(body: DeleteMeRequest(confirmation: confirmation));
}
