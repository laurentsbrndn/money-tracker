import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/network/api_client_provider.dart';
import '../../../core/network/generated/models/auth_response.dart';
import '../data/auth_repository.dart';
import '../data/google_sign_in_service.dart';

part 'auth_actions.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    AuthRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
GoogleSignInService googleSignInService(Ref ref) => GoogleSignInService();

/// The auth use cases the screens call. A successful login/register starts the
/// session; the router then moves on by itself. Errors are thrown for the
/// screen to show with `describeError`.
@Riverpod(keepAlive: true)
AuthActions authActions(Ref ref) => AuthActions(ref);

class AuthActions {
  AuthActions(this._ref);

  final Ref _ref;

  AuthRepository get _repository => _ref.read(authRepositoryProvider);

  SessionController get _session =>
      _ref.read(sessionControllerProvider.notifier);

  Future<void> login({
    required String email,
    required String password,
    bool discardLocalData = false,
  }) async {
    final response = await _repository.login(email: email, password: password);
    await _session.establish(response, discardLocalData: discardLocalData);
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    bool discardLocalData = false,
  }) async {
    final response = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    await _session.establish(response, discardLocalData: discardLocalData);
  }

  /// Returns false when the user dismissed the Google sheet.
  Future<bool> loginWithGoogle({bool discardLocalData = false}) async {
    final idToken = await _ref.read(googleSignInServiceProvider).pickIdToken();
    if (idToken == null) {
      return false;
    }
    final AuthResponse response = await _repository.loginWithGoogle(idToken);
    await _session.establish(response, discardLocalData: discardLocalData);
    return true;
  }

  Future<void> forgotPassword(String email) =>
      _repository.forgotPassword(email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _repository.resetPassword(
    email: email,
    code: code,
    newPassword: newPassword,
  );

  Future<void> verifyEmail(String code) async {
    final user = await _repository.verifyEmail(code);
    await _session.updateUser(user);
  }

  Future<void> resendEmailVerification() =>
      _repository.resendEmailVerification();
}
