import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/auth/session_controller.dart';
import 'core/database/app_database_provider.dart';
import 'core/database/connection.dart';
import 'core/sync/sync_background.dart';

/// Initialises app-wide services, then starts the widget tree.
/// Later phases add timezone and RevenueCat setup here.
Future<void> bootstrap() async {
  await registerBackgroundSync();
  final database = await openAppDatabase();
  final container = ProviderContainer(
    overrides: [initialDatabaseProvider.overrideWithValue(database)],
  );
  await container.read(sessionControllerProvider.notifier).load();
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
