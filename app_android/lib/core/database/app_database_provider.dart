import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'connection.dart';

/// Overridden in `bootstrap()` (and in the background sync isolate) with the
/// opened, encrypted database.
final initialDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('initialDatabaseProvider must be overridden'),
);

/// The database every feature reads. Logout replaces it with a fresh one, so
/// everything that watches [appDatabaseProvider] rebuilds on the new instance.
final appDatabaseProvider = NotifierProvider<AppDatabaseHolder, AppDatabase>(
  AppDatabaseHolder.new,
);

class AppDatabaseHolder extends Notifier<AppDatabase> {
  @override
  AppDatabase build() => ref.watch(initialDatabaseProvider);

  /// Deletes the local database and key, then opens an empty one.
  Future<void> wipeAndReopen() async {
    await wipeAppDatabase(state);
    state = await openAppDatabase();
  }
}
