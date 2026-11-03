import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database_provider.dart';
import '../database/connection.dart';
import '../time/timestamp_format.dart';
import 'sync_engine.dart';
import 'sync_scheduler.dart';

const String _uniqueName = 'moneytracker.periodic_sync';
const String _taskName = 'periodic_sync';

/// Entry point of the Workmanager isolate (FRONTEND_FLUTTER §4.3).
@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final database = await openAppDatabase();
    final container = ProviderContainer(
      overrides: [initialDatabaseProvider.overrideWithValue(database)],
    );
    try {
      final foreground = await database.syncStateDao.read(foregroundSinceKey);
      if (foreground != null && foreground.isNotEmpty) {
        final since = parseTimestamp(foreground);
        if (DateTime.now().difference(since) < foregroundMarkerMaxAge) {
          return true;
        }
      }
      await container.read(sessionControllerProvider.notifier).load();
      final signedIn =
          container.read(sessionControllerProvider).status ==
          SessionStatus.authenticated;
      final initialDone =
          await database.syncStateDao.read(initialSyncDoneKey) == 'true';
      if (signedIn && initialDone) {
        await container.read(syncEngineProvider.notifier).runOnce();
      }
      return true;
    } on Object {
      // The next periodic run tries again.
      return false;
    } finally {
      container.dispose();
      await database.close();
    }
  });
}

/// Registers the 30-minute periodic sync, only while a network is available.
Future<void> registerBackgroundSync() async {
  await Workmanager().initialize(syncCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _uniqueName,
    _taskName,
    frequency: const Duration(minutes: 30),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}
