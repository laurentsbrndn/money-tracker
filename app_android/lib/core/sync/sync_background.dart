import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';

import '../../l10n/generated/app_localizations_id.dart';
import '../auth/session_controller.dart';
import '../auth/session_state.dart';
import '../database/app_database.dart';
import '../database/app_database_provider.dart';
import '../database/connection.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/notification_service.dart';
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
        await _refreshNotifications(database);
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

/// A sync may have pulled changes to settings or data from another device, so
/// the notification schedule and budget warnings are rebuilt here too. A
/// failure must not fail the sync task.
Future<void> _refreshNotifications(AppDatabase database) async {
  try {
    tz_data.initializeTimeZones();
    final l10n = AppLocalizationsId();
    final service = NotificationService(
      remindersChannelName: l10n.notifChannelReminders,
      budgetChannelName: l10n.notifChannelBudget,
    );
    await NotificationScheduler(db: database, service: service).refresh();
    service.dispose();
  } on Object {
    // The next app open or sync rebuilds it.
  }
}
