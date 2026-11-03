import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

/// Thrown when Google sign-in cannot be used (misconfigured build).
class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable();
}

/// Google sign-in through Credential Manager (FRONTEND_FLUTTER §1). Only the
/// ID token is needed; the server verifies it.
class GoogleSignInService {
  bool _initialized = false;

  /// The Google ID token, or null if the user dismissed the sheet.
  Future<String?> pickIdToken() async {
    if (AppConfig.googleServerClientId.isEmpty) {
      throw const GoogleSignInUnavailable();
    }
    if (!_initialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );
      _initialized = true;
    }
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> signOut() => GoogleSignIn.instance.signOut();
}
