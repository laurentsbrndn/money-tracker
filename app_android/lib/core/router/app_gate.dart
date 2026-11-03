import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';

part 'app_gate.g.dart';

/// Where the app must be, whatever the user taps (APP_FLOWS Flow 1).
enum AppGate {
  /// Session or database flags not read yet.
  loading,

  /// No session: onboarding and the auth screens.
  signedOut,

  /// Signed in, the first pull has not finished.
  initialSync,

  /// New user who has not finished or skipped the setup wizard.
  setup,
  ready,
}

@Riverpod(keepAlive: true)
Stream<Map<String, String>> syncFlags(Ref ref) =>
    ref.watch(appDatabaseProvider).syncStateDao.watchAll();

@Riverpod(keepAlive: true)
AppGate appGate(Ref ref) {
  final session = ref.watch(sessionControllerProvider);
  switch (session.status) {
    case SessionStatus.loading:
      return AppGate.loading;
    case SessionStatus.signedOut:
      return AppGate.signedOut;
    case SessionStatus.authenticated:
    case SessionStatus.needsLogin:
      final flags = ref.watch(syncFlagsProvider).value;
      if (flags == null) {
        return AppGate.loading;
      }
      if (flags[initialSyncDoneKey] != 'true') {
        return AppGate.initialSync;
      }
      if (flags[setupPendingKey] == 'true') {
        return AppGate.setup;
      }
      return AppGate.ready;
  }
}
