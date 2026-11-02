import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/connection.dart';

/// Initialises app-wide services, then starts the widget tree.
/// Later phases add timezone, RevenueCat, and Workmanager setup here.
Future<void> bootstrap() async {
  final database = await openAppDatabase();
  runApp(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: const App(),
    ),
  );
}
