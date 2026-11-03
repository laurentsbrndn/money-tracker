import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/user_settings_repository.dart';

part 'user_settings_actions.g.dart';

@Riverpod(keepAlive: true)
UserSettingsRepository userSettingsRepository(Ref ref) =>
    UserSettingsRepository(
      db: ref.watch(appDatabaseProvider),
      writer: ref.watch(outboxWriterProvider),
    );
