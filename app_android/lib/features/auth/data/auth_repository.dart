import '../../../core/auth/session_user.dart';
import '../../../core/network/generated/models/auth_response.dart';
import '../../../core/network/generated/models/forgot_password_request.dart';
import '../../../core/network/generated/models/google_login_request.dart';
import '../../../core/network/generated/models/login_request.dart';
import '../../../core/network/generated/models/register_request.dart';
import '../../../core/network/generated/models/reset_password_request.dart';
import '../../../core/network/generated/models/verify_email_request.dart';
import '../../../core/network/generated/money_tracker_api.dart';
import '../../../core/time/device_timezone.dart';

/// Online-only auth calls (ARCHITECTURE §4). Starting the session from the
/// response is left to the caller.
class AuthRepository {
  const AuthRepository(this._api);

  final MoneyTrackerApi _api;

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async => _api.auth.register(
    body: RegisterRequest(
      name: name,
      email: email,
      password: password,
      timezone: await detectDeviceTimezone(),
    ),
  );

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) => _api.auth.login(
    body: LoginRequest(email: email, password: password),
  );

  Future<AuthResponse> loginWithGoogle(String idToken) async =>
      _api.auth.loginWithGoogle(
        body: GoogleLoginRequest(
          idToken: idToken,
          timezone: await detectDeviceTimezone(),
        ),
      );

  Future<void> forgotPassword(String email) =>
      _api.auth.forgotPassword(body: ForgotPasswordRequest(email: email));

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _api.auth.resetPassword(
    body: ResetPasswordRequest(
      email: email,
      code: code,
      newPassword: newPassword,
    ),
  );

  Future<SessionUser> verifyEmail(String code) async {
    final envelope = await _api.auth.verifyEmail(
      body: VerifyEmailRequest(code: code),
    );
    return SessionUser.fromApi(envelope.user);
  }

  Future<void> resendEmailVerification() => _api.auth.resendEmailVerification();
}
