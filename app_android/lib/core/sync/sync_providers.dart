import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database_provider.dart';
import '../network/api_client_provider.dart';
import 'entity_stores.dart';
import 'failed_changes_service.dart';
import 'outbox_writer.dart';
import 'pull_applier.dart';
import 'push_applier.dart';
import 'sync_remote.dart';
import 'sync_scheduler.dart';

part 'sync_providers.g.dart';

@Riverpod(keepAlive: true)
EntityStores entityStores(Ref ref) =>
    EntityStores(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
SyncRemote syncRemote(Ref ref) => SyncRemote(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
PushApplier pushApplier(Ref ref) => PushApplier(
  ref.watch(appDatabaseProvider),
  ref.watch(entityStoresProvider),
);

@Riverpod(keepAlive: true)
PullApplier pullApplier(Ref ref) => PullApplier(
  ref.watch(appDatabaseProvider),
  ref.watch(entityStoresProvider),
);

/// The only way screens' repositories write synced data (FRONTEND_FLUTTER §3).
@Riverpod(keepAlive: true)
OutboxWriter outboxWriter(Ref ref) => OutboxWriter(
  db: ref.watch(appDatabaseProvider),
  stores: ref.watch(entityStoresProvider),
  onCommitted: () => ref.read(syncSchedulerProvider).requestSync(),
);

@Riverpod(keepAlive: true)
FailedChangesService failedChangesService(Ref ref) => FailedChangesService(
  db: ref.watch(appDatabaseProvider),
  stores: ref.watch(entityStoresProvider),
  writer: ref.watch(outboxWriterProvider),
  remote: ref.watch(syncRemoteProvider),
);
