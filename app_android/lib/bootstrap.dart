import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'app.dart';
import 'core/auth/session_controller.dart';
import 'core/billing/billing_providers.dart';
import 'core/database/app_database_provider.dart';
import 'core/database/connection.dart';
import 'core/security/app_lock_controller.dart';
import 'core/sync/sync_background.dart';
import 'features/export/application/export_providers.dart';

/// Initialises app-wide services, then starts the widget tree.
Future<void> bootstrap() async {
  // The timezone database backs `UserClock` and the notification schedule.
  tz_data.initializeTimeZones();
  await registerBackgroundSync();
  final database = await openAppDatabase();
  final container = ProviderContainer(
    overrides: [initialDatabaseProvider.overrideWithValue(database)],
  );
  await container.read(sessionControllerProvider.notifier).load();
  // RevenueCat starts under the signed-in user (no anonymous id in between);
  // without a key in this build it stays off and the paywall says so.
  await container
      .read(billingServiceProvider)
      .configure(userId: container.read(sessionControllerProvider).user?.id);
  // Read the PIN state before the first frame so a locked app never flashes
  // its content.
  await container.read(appLockControllerProvider.notifier).load();
  // Export files hold real amounts: drop any left from the last run.
  await container.read(exportFileServiceProvider).cleanUp();
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
